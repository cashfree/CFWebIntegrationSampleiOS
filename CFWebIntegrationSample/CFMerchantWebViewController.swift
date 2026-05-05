//
//  CFMerchantWebViewController.swift
//  CFWebIntegrationSample
//

import UIKit
import WebKit

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

class CFMerchantWebViewController: UIViewController {

    // MARK: - Configuration (set before presenting)
    var merchantURL: String = ""

    // MARK: - Callbacks
    var onPaymentComplete: (() -> Void)?
    var onPaymentFailed: ((String) -> Void)?

    private var webView: WKWebView!
    private var loader: UIActivityIndicatorView!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupWebView()
        setupLoader()
        loadMerchantPage()
    }

    deinit {
        webView?.configuration.userContentController
            .removeScriptMessageHandler(forName: "nativeProcess")
    }

    // MARK: - WebView Setup
    private func setupWebView() {
        let controller = WKUserContentController()
        controller.add(self, name: "nativeProcess")   // ← JS bridge registration

        let config = WKWebViewConfiguration()
        config.userContentController = controller

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webView)
    }

    // MARK: - Load Merchant Page
    private func loadMerchantPage() {
        guard let url = URL(string: merchantURL), !merchantURL.isEmpty else {
            showError("Invalid merchant URL: \(merchantURL)")
            return
        }
        webView.load(URLRequest(url: url))
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
            self?.onPaymentComplete?()
        }
    }

    private func finishWithFailure(message: String) {
        dismiss(animated: true) { [weak self] in
            self?.onPaymentFailed?(message)
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
}

extension CFMerchantWebViewController: WKScriptMessageHandler {

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        var msg = message.body as? String ?? ""

        if msg == "getAppList" {
            let apps = installedUPIApps()
            guard let data = try? JSONSerialization.data(withJSONObject: apps),
                  let json = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self.webView.evaluateJavaScript("window.receiveAppList(\(json))")
            }

        } else if isUPIDeepLink(msg) {
            if msg.contains("paytm:") {
                msg = msg.replacingOccurrences(of: "paytm:", with: "paytmmp:")
            }
            DispatchQueue.main.async {
                self.webView.evaluateJavaScript("verifyPaymentForiOS()") { (val, error) in
                    guard let url = URL(string: msg),
                          UIApplication.shared.canOpenURL(url) else { return }
                    UIApplication.shared.open(url)
                }
            }

        } else if msg == "dismissLoader" {
            hideLoader()

        } else if msg == "dismissWeb" {
            finishWithSuccess()
        }
    }

    private func isUPIDeepLink(_ msg: String) -> Bool {
        return msg.contains("paytm") || msg.contains("phonepe") || msg.contains("tez") || msg.contains("bhim") || msg.contains("cred") || msg.contains("amazon") || msg.contains("whatsapp-consumer") || msg.contains("navi") || msg.contains("mobikwik") || msg.contains("myairtel")  || msg.contains("popclub") || msg.contains("kiwi") || msg.contains("super") || msg.contains("simplypayupi")
    }
    
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
extension CFMerchantWebViewController: WKUIDelegate {}

// MARK: - WKNavigationDelegate
extension CFMerchantWebViewController: WKNavigationDelegate {

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
        // Cancel so WKWebView doesn't try to load a scheme it cannot handle
        decisionHandler(.cancel)

        let fragment = navigationAction.request.url?.fragment?.removingPercentEncoding
        handlePaymentReturn(fragment: fragment)
        webView.loadHTMLString("", baseURL: nil)   // clear page so it isn't shown on reopen
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

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        hideLoader()
        showError("Failed to load page:\n\(error.localizedDescription)")
    }
}
