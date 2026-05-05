//
//  CFWebIntegrationViewController.swift
//  CFWebIntegrationSample
//

import UIKit
import WebKit

// MARK: - Supported UPI Apps
// Each entry: (display name shown to user, URL scheme to check canOpenURL)
// Must match LSApplicationQueriesSchemes in Info.plist

private let upiApps = [
    [
        "displayName": "GOOGLEPAY",
        "id": "tez://",
    ],
    [
        "displayName": "PAYTM",
        "id": "paytmmp://",
    ],
    [
        "displayName": "PHONEPE",
        "id": "phonepe://",
    ],
    [
        "displayName": "BHIM",
        "id": "bhim://",
    ],
    [
        "displayName": "CRED",
        "id": "credpay://",
    ],
    [
        "displayName": "AMAZONPAY",
        "id": "amazonpay://",
    ],
    [
        "displayName": "WHATSAPP",
        "id": "whatsapp-consumer://",
    ],
    [
        "displayName": "NAVI",
        "id": "navipay://",
    ],
    [
        "displayName": "MOBIKWIK",
        "id": "mobikwik://",
    ],
    [
        "displayName": "AIRTEL",
        "id": "myairtel://",
    ],
    [
        "displayName": "POP",
        "id": "popclubapp://",
    ],
    [
        "displayName": "SUPERMONEY",
        "id": "super://",
    ],
    [
        "displayName": "KIWI",
        "id": "kiwi://",
    ],
    [
        "displayName": "SIMPLYPAY",
        "id": "simplypayupi://",
    ]
]

class CFWebIntegrationViewController: UIViewController {

    // MARK: - Configuration (set before presenting)
    var paymentSessionId: String = ""
    var orderId:          String = ""
    var environment      = "SANDBOX"   // "SANDBOX" or "PRODUCTION"

    // MARK: - Callbacks
    var onPaymentComplete: ((String) -> Void)?   // orderId
    var onPaymentFailed:   ((String, String) -> Void)?  // (message, orderId)

    private var webView: WKWebView!
    private var loader:  UIActivityIndicatorView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupWebView()
        setupLoader()
        loadPaymentForm()
    }

    deinit {
        // Required: WKUserContentController retains its message handler strongly.
        // Removing it here prevents a memory leak.
        webView?.configuration.userContentController
            .removeScriptMessageHandler(forName: "nativeProcess")
    }

    // MARK: - WebView Setup
    // Cashfree JS SDK detects iOS via window.webkit.messageHandlers
    // and posts all messages to the handler named "nativeProcess".

    private func setupWebView() {
        let controller = WKUserContentController()
        controller.add(self, name: "nativeProcess")

        let config = WKWebViewConfiguration()
        config.userContentController = controller

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webView)
    }

    // MARK: - Load Payment Form
    private func loadPaymentForm() {
        var secureURL = ""
        if environment == "SANDBOX" {
            secureURL = "https://sandbox.cashfree.com/pg/view/sessions/checkout/app"
        } else {
            secureURL = "https://api.cashfree.com/pg/view/sessions/checkout/app"
        }
        var paymentInputFormHtml =
            "<html>"
                + "<body>"
                + "<form id=\'redirectForm\' name=\'order\' action=\'\(secureURL)\' method=\'post\'>"
        paymentInputFormHtml += "<input type=\'hidden\' name=\'payment_session_id\' value=\'\(paymentSessionId)\'/>" +
            "</form>" +
        "<script\n" +
                        " type=\"text/javascript\">\t window.onload = function () { const form = document.getElementById(\"redirectForm\"); const meta = { userAgent: window.navigator.userAgent, }; const sortedMeta = Object.entries(meta).sort().reduce((o, [k, v]) => { o[k] = v; return o; }, {}); const base64Meta = btoa(JSON.stringify(sortedMeta)); FN = document.createElement('input'); FN.setAttribute('type', 'hidden'); FN.setAttribute('name', 'browser_meta'); FN.setAttribute('value', base64Meta); form.appendChild(FN); form.submit(); }  </script>\n"
            + "</body>"
            + "</html>";
        webView.loadHTMLString(paymentInputFormHtml, baseURL: nil)
    }

    // MARK: - Loader
    private func setupLoader() {
        loader = UIActivityIndicatorView(style: .large)
        loader.color = .systemGray
        loader.center = view.center
        loader.hidesWhenStopped = true
        loader.startAnimating()
        view.addSubview(loader)
    }

    private func hideLoader() {
        DispatchQueue.main.async { self.loader.stopAnimating() }
    }

    private func finishWithSuccess() {
        dismiss(animated: true) { [weak self] in
            guard let self else { return }
            self.onPaymentComplete?(self.orderId)
        }
    }

    private func finishWithFailure(message: String) {
        dismiss(animated: true) { [weak self] in
            guard let self else { return }
            self.onPaymentFailed?(message, self.orderId)
        }
    }
}

extension CFWebIntegrationViewController: WKScriptMessageHandler {

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        var msg = message.body as? String ?? ""

        switch true {

        case msg == "getAppList":
            let apps = installedUPIApps()
            guard let data = try? JSONSerialization.data(withJSONObject: apps),
                  let json = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self.webView.evaluateJavaScript("window.receiveAppList(\(json))")
            }

        case isUPIDeepLink(msg):
            // Paytm registers "paytm:" in some flows but the installed app handles "paytmmp:"
            if msg.contains("paytm:") {
                msg = msg.replacingOccurrences(of: "paytm:", with: "paytmmp:")
            }
            DispatchQueue.main.async {
                self.webView.evaluateJavaScript("verifyPaymentForiOS()") { [weak self] _, _ in
                    guard let url = URL(string: msg),
                          UIApplication.shared.canOpenURL(url) else { return }
                    UIApplication.shared.open(url)
                }
            }

        case msg == "dismissLoader":
            hideLoader()

        case msg == "dismissWeb":
            finishWithSuccess()

        default:
            break
        }
    }

    // Returns true if the message body is a UPI intent deep-link URL
    private func isUPIDeepLink(_ msg: String) -> Bool {
        return msg.contains("paytm") || msg.contains("phonepe") || msg.contains("tez") || msg.contains("bhim") || msg.contains("cred") || msg.contains("amazon") || msg.contains("whatsapp-consumer") || msg.contains("navi") || msg.contains("payz") || msg.contains("mobikwik")  || msg.contains("freecharge")  || msg.contains("myairtel")  || msg.contains("popclub") || msg.contains("slice") || msg.contains("kiwi") || msg.contains("super") || msg.contains("simplypayupi")
    }

    // Filters upiApps to only those actually installed on this device.
    // canOpenURL works only for schemes declared in LSApplicationQueriesSchemes (Info.plist).
    private func installedUPIApps() -> [[String: String]] {
        var installedApps = [[String: String]]()
        for app in upiApps {
            let url = app["id"] ?? ""
            if UIApplication.shared.canOpenURL(URL(string: url)!) {
                installedApps.append(app)
            }
        }
        return installedApps
    }
}

// MARK: - WKUIDelegate
// Required for uiDelegate — allows checkout page to use window.open() and JS dialogs.
extension CFWebIntegrationViewController: WKUIDelegate {}

// MARK: - WKNavigationDelegate
extension CFWebIntegrationViewController: WKNavigationDelegate {

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        let scheme = navigationAction.request.url?.scheme ?? ""
        guard scheme.hasPrefix("nextgenapi-") || scheme.hasPrefix("nga-") else {
            decisionHandler(.allow)
            return
        }
        // Cancel so WKWebView doesn't attempt to load the custom scheme (which would fail)
        decisionHandler(.cancel)

        let fragment = navigationAction.request.url?.fragment?.removingPercentEncoding
        handlePaymentReturn(fragment: fragment)
        webView.loadHTMLString("", baseURL: nil)   // clear so old page isn't shown on reopen
    }

    private func handlePaymentReturn(fragment: String?) {
        guard
            let fragment,
            let data   = fragment.data(using: .utf8),
            let output = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            !output.isEmpty
        else {
            finishWithSuccess()
            return
        }

        let status = (output["txStatus"] as? String ?? "").lowercased()
        let txMsg  = output["txMsg"]   as? String ?? "Transaction failed"

        switch status {
        case "failed", "pending":
            finishWithFailure(message: txMsg)
        default:
            finishWithSuccess()
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        hideLoader()
    }
}

// MARK: - INFO.PLIST SETUP
//
// Add the following to your Info.plist.
// Without this, canOpenURL() always returns false and no UPI apps will appear.
//
// <key>LSApplicationQueriesSchemes</key>
// <array>
//     <string>tez</string>
//     <string>phonepe</string>
//     <string>paytmmp</string>
//     <string>bhim</string>
//     <string>credpay</string>
//     <string>amazonpay</string>
//     <string>whatsapp-consumer</string>
//     <string>navipay</string>
//     <string>mobikwik</string>
//     <string>myairtel</string>
//     <string>popclubapp</string>
//     <string>super</string>
//     <string>kiwi</string>
//     <string>simplypayupi</string>
// </array>
