//
//  ViewController.swift
//  CFWebIntegrationSample
//
//  Two integration modes:
//
//  MODE 1 — Native/SDK Integration (top section)
//    Merchant's server creates an order → native gets payment_session_id
//    → CFWebIntegrationViewController POSTs the form to Cashfree checkout
//
//  MODE 2 — Merchant URL Integration (bottom section)
//    Merchant's own website already embeds the Cashfree JS SDK and calls
//    cashfree.checkout() itself. Native just loads that URL in a WKWebView
//    with the nativeProcess bridge pre-registered.
//    → CFMerchantWebViewController
//

import UIKit

class ViewController: UIViewController {

    // MARK: - Mode 1: Native Integration UI
    private let logoLabel      = UILabel()
    private let subtitleLabel  = UILabel()
    private let divider        = UIView()
    private let sessionLabel   = UILabel()
    private let sessionField   = UITextField()
    private let orLabel        = UILabel()
    private let createButton   = UIButton(type: .system)
    private let payButton      = UIButton(type: .system)
    private let spinner        = UIActivityIndicatorView(style: .medium)
    private let statusLabel    = UILabel()

    // MARK: - Mode 2: Merchant URL Integration UI
    private let divider2       = UIView()
    private let mode2Title     = UILabel()
    private let mode2Subtitle  = UILabel()
    private let urlLabel       = UILabel()
    private let urlField       = UITextField()
    private let loadURLButton  = UIButton(type: .system)

    // Class-level so keyboard handlers can reference it
    private let scrollView     = UIScrollView()

    // MARK: - Sandbox credentials (Mode 1 only)
    private let sandboxAppId     = "TEST430329ae80e0f32e41a393d78b923034"
    private let sandboxSecretKey = "TESTaf195616268bd6202eeb3bf8dc458956e7192a85"
    private let environment      = "SANDBOX"

    private var paymentSessionId = ""
    private var orderId          = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Cashfree JS SDK"
        view.backgroundColor = .systemBackground
        buildUI()
        setupKeyboard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)),
                                               name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)),
                                               name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - UI Setup

    private func buildUI() {
        // ── Mode 1 ──────────────────────────────────────────────────────
        logoLabel.text = "Cashfree"
        logoLabel.font = .boldSystemFont(ofSize: 28)
        logoLabel.textColor = .label
        logoLabel.textAlignment = .center

        subtitleLabel.text = "Mode 1 · Native / SDK Integration"
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center

        divider.backgroundColor = .separator

        sessionLabel.text = "Payment Session ID"
        sessionLabel.font = .systemFont(ofSize: 13, weight: .medium)
        sessionLabel.textColor = .secondaryLabel

        sessionField.placeholder = "Paste payment_session_id from your server"
        sessionField.borderStyle = .roundedRect
        sessionField.autocorrectionType = .no
        sessionField.autocapitalizationType = .none
        sessionField.font = .systemFont(ofSize: 14)
        sessionField.addTarget(self, action: #selector(sessionFieldChanged), for: .editingChanged)

        orLabel.text = "— OR create a sandbox test order below —"
        orLabel.font = .systemFont(ofSize: 12)
        orLabel.textColor = .tertiaryLabel
        orLabel.textAlignment = .center

        createButton.setTitle("Create Test Order", for: .normal)
        createButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        createButton.backgroundColor = .secondarySystemBackground
        createButton.setTitleColor(.label, for: .normal)
        createButton.layer.cornerRadius = 10
        createButton.layer.borderWidth = 1
        createButton.layer.borderColor = UIColor.separator.cgColor
        createButton.addTarget(self, action: #selector(createOrderTapped), for: .touchUpInside)

        payButton.setTitle("Start Payment (SDK)", for: .normal)
        payButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        payButton.backgroundColor = UIColor(red: 0.27, green: 0.25, blue: 0.83, alpha: 1)
        payButton.setTitleColor(.white, for: .normal)
        payButton.layer.cornerRadius = 12
        payButton.isEnabled = false
        payButton.alpha = 0.5
        payButton.addTarget(self, action: #selector(payNowTapped), for: .touchUpInside)

        spinner.hidesWhenStopped = true

        statusLabel.text = ""
        statusLabel.font = .systemFont(ofSize: 13)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2

        // ── Mode 2 ──────────────────────────────────────────────────────
        divider2.backgroundColor = .separator

        mode2Title.text = "Mode 2 · Merchant URL Integration"
        mode2Title.font = .boldSystemFont(ofSize: 15)
        mode2Title.textColor = .label
        mode2Title.textAlignment = .center

        mode2Subtitle.text = "Merchant's own page embeds the Cashfree JS SDK.\n" +
                             "Native loads the URL — JS bridge registers automatically."
        mode2Subtitle.font = .systemFont(ofSize: 12)
        mode2Subtitle.textColor = .secondaryLabel
        mode2Subtitle.textAlignment = .center
        mode2Subtitle.numberOfLines = 0

        urlLabel.text = "Merchant Checkout URL"
        urlLabel.font = .systemFont(ofSize: 13, weight: .medium)
        urlLabel.textColor = .secondaryLabel

        urlField.placeholder = "https://merchant.com/checkout"
        urlField.borderStyle = .roundedRect
        urlField.autocorrectionType = .no
        urlField.autocapitalizationType = .none
        urlField.keyboardType = .URL
        urlField.font = .systemFont(ofSize: 14)
        urlField.addTarget(self, action: #selector(urlFieldChanged), for: .editingChanged)

        loadURLButton.setTitle("Open Merchant URL", for: .normal)
        loadURLButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        loadURLButton.backgroundColor = UIColor(red: 0.13, green: 0.55, blue: 0.13, alpha: 1)
        loadURLButton.setTitleColor(.white, for: .normal)
        loadURLButton.layer.cornerRadius = 12
        loadURLButton.isEnabled = false
        loadURLButton.alpha = 0.5
        loadURLButton.addTarget(self, action: #selector(loadURLTapped), for: .touchUpInside)

        // ── Stack ────────────────────────────────────────────────────────
        // scrollView is a class property so keyboard handlers can adjust its inset
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive   // drag to dismiss keyboard
        view.addSubview(scrollView)

        let stack = UIStackView(arrangedSubviews: [
            // Mode 1
            logoLabel, subtitleLabel, divider,
            sessionLabel, sessionField,
            orLabel, createButton,
            spinner, statusLabel,
            payButton,
            // Mode 2
            divider2,
            mode2Title, mode2Subtitle,
            urlLabel, urlField,
            loadURLButton
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(4,  after: logoLabel)
        stack.setCustomSpacing(16, after: subtitleLabel)
        stack.setCustomSpacing(16, after: divider)
        stack.setCustomSpacing(6,  after: sessionLabel)
        stack.setCustomSpacing(16, after: sessionField)
        stack.setCustomSpacing(12, after: orLabel)
        stack.setCustomSpacing(4,  after: createButton)
        stack.setCustomSpacing(2,  after: spinner)
        stack.setCustomSpacing(14, after: statusLabel)
        stack.setCustomSpacing(24, after: payButton)
        stack.setCustomSpacing(20, after: divider2)
        stack.setCustomSpacing(6,  after: mode2Title)
        stack.setCustomSpacing(16, after: mode2Subtitle)
        stack.setCustomSpacing(6,  after: urlLabel)
        stack.setCustomSpacing(16, after: urlField)
        stack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(stack)

        // For UIScrollView + Auto Layout:
        //   • contentLayoutGuide anchors define the scrollable content size
        //   • frameLayoutGuide.widthAnchor pins the stack width to the visible frame
        //     (this tells Auto Layout the scroll direction is vertical, not horizontal)
        let content = scrollView.contentLayoutGuide
        let frame   = scrollView.frameLayoutGuide

        NSLayoutConstraint.activate([
            // Scroll view fills the safe area
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // Stack is pinned to contentLayoutGuide — this drives the scroll height
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 32),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -40),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),

            // Width is pinned to frameLayoutGuide — prevents horizontal scrolling
            stack.widthAnchor.constraint(equalTo: frame.widthAnchor, constant: -48),

            divider.heightAnchor.constraint(equalToConstant: 0.5),
            divider2.heightAnchor.constraint(equalToConstant: 0.5),
            createButton.heightAnchor.constraint(equalToConstant: 48),
            payButton.heightAnchor.constraint(equalToConstant: 52),
            sessionField.heightAnchor.constraint(equalToConstant: 44),
            urlField.heightAnchor.constraint(equalToConstant: 44),
            loadURLButton.heightAnchor.constraint(equalToConstant: 52),
        ])
    }

    // MARK: - Keyboard Handling

    private func setupKeyboard() {
        // Tap anywhere on the scroll view (outside a text field) to dismiss keyboard
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false   // still lets buttons receive taps
        scrollView.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let info = notification.userInfo,
              let keyboardFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
        else { return }
        // Push scrollView content up so bottom items (urlField, loadURLButton) remain reachable
        let bottomInset = keyboardFrame.height - view.safeAreaInsets.bottom
        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset.bottom = bottomInset
            self.scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
        else { return }
        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset.bottom = 0
            self.scrollView.verticalScrollIndicatorInsets.bottom = 0
        }
    }

    // MARK: - Mode 1 Actions

    @objc private func sessionFieldChanged() {
        let text = sessionField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        paymentSessionId = text
        updateButton(payButton, enabled: !text.isEmpty)
    }

    @objc private func createOrderTapped() {
        setLoading(true, status: "Creating order...")
        createSandboxOrder { [weak self] sessionId, orderId in
            guard let self else { return }
            DispatchQueue.main.async {
                self.setLoading(false, status: "")
                if sessionId.isEmpty {
                    self.showAlert("Failed to create order. Check credentials.")
                    return
                }
                self.paymentSessionId = sessionId
                self.orderId = orderId
                self.sessionField.text = sessionId
                self.statusLabel.text = "Order created: \(orderId)"
                self.updateButton(self.payButton, enabled: true)
            }
        }
    }

    @objc private func payNowTapped() {
        guard !paymentSessionId.isEmpty else { return }

        let vc = CFWebIntegrationViewController()
        vc.paymentSessionId = paymentSessionId
        vc.orderId          = orderId.isEmpty ? "order_unknown" : orderId
        vc.environment      = environment
        vc.modalPresentationStyle = .fullScreen

        vc.onPaymentComplete = { [weak self] orderId in
            self?.showAlert("Payment done!\n\nVerify order \(orderId) on your server.")
        }
        vc.onPaymentFailed = { [weak self] message, _ in
            self?.showAlert("Payment failed:\n\(message)")
        }

        present(vc, animated: true)
    }

    // MARK: - Mode 2 Actions

    @objc private func urlFieldChanged() {
        let text = urlField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        updateButton(loadURLButton, enabled: !text.isEmpty)
    }

    @objc private func loadURLTapped() {
        let url = urlField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !url.isEmpty else { return }
        urlField.resignFirstResponder()

        let vc = CFMerchantWebViewController()
        vc.merchantURL = url
        vc.modalPresentationStyle = .fullScreen

        // Called when the Cashfree JS SDK posts "dismissWeb"
        vc.onPaymentComplete = { [weak self] in
            self?.showAlert("Payment complete!\n\nVerify the order status on your server.")
        }
        // Called when nextgenapi-/nga- return URL signals failure/pending
        vc.onPaymentFailed = { [weak self] message in
            self?.showAlert("Payment failed:\n\(message)")
        }

        present(vc, animated: true)
    }

    // MARK: - Helpers

    private func updateButton(_ button: UIButton, enabled: Bool) {
        button.isEnabled = enabled
        UIView.animate(withDuration: 0.2) { button.alpha = enabled ? 1.0 : 0.5 }
    }

    private func setLoading(_ loading: Bool, status: String) {
        DispatchQueue.main.async {
            loading ? self.spinner.startAnimating() : self.spinner.stopAnimating()
            self.statusLabel.text = status
            self.createButton.isEnabled = !loading
        }
    }

    private func showAlert(_ message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Cashfree", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
        }
    }

    // MARK: - Sandbox Order Creation
    // WARNING: Never call Cashfree's order API directly from a mobile app in production.
    // Your server must create orders and return only the payment_session_id to the app.
    // This is here only to make the sample runnable without a backend.

    private func createSandboxOrder(completion: @escaping (String, String) -> Void) {
        let url = URL(string: "https://sandbox.cashfree.com/pg/orders")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = [
            "Content-Type":    "application/json",
            "x-client-id":     sandboxAppId,
            "x-client-secret": sandboxSecretKey,
            "x-api-version":   "2023-08-01"
        ]

        let orderId = "order_ios_\(Int.random(in: 100000...999999))"
        let body: [String: Any] = [
            "order_id":       orderId,
            "order_amount":   1.00,
            "order_currency": "INR",
            "customer_details": [
                "customer_id":    "test_customer_001",
                "customer_name":  "Test User",
                "customer_email": "test@cashfree.com",
                "customer_phone": "9999999999"
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard error == nil, let data else {
                completion("", "")
                return
            }
            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let sessionId = json["payment_session_id"] as? String ?? ""
            let returnedOrderId = json["order_id"] as? String ?? orderId
            completion(sessionId, returnedOrderId)
        }.resume()
    }
}
