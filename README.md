# Cashfree Web Integration Sample — iOS

A sample iOS app demonstrating how to integrate the **Cashfree JS SDK** inside a native `WKWebView`. This covers two distinct integration modes so merchants can pick the one that fits their setup.

---

## Requirements

- iOS 13.0+
- Xcode 26
- Swift 5
- No third-party dependencies — uses only `UIKit` and `WebKit`

---

## Project Structure

```
CFWebIntegrationSample/
├── CFWebIntegrationViewController.swift   // Mode 1 — Native / SDK flow
├── CFMerchantWebViewController.swift      // Mode 2 — Merchant URL flow
├── ViewController.swift                   // Sample home screen (both modes)
├── AppDelegate.swift
├── SceneDelegate.swift
└── Info.plist                             // LSApplicationQueriesSchemes required
```

---

## Two Integration Modes

### Mode 1 — Native / SDK Integration (`CFWebIntegrationViewController`)

Use this when your **native app** is responsible for creating the Cashfree order and starting checkout.

**Flow:**
1. Your server creates a Cashfree order and returns `payment_session_id` + `order_id` to the app
2. Native app passes these to `CFWebIntegrationViewController`
3. The controller builds an HTML form and POSTs it to Cashfree's checkout endpoint
4. Cashfree's checkout page loads inside the `WKWebView`
5. On payment completion, Cashfree redirects to a custom URL scheme (`nextgenapi-...`) which the native app intercepts and parses

```swift
let vc = CFWebIntegrationViewController()
vc.paymentSessionId = "session_id_from_your_server"
vc.orderId          = "order_id_from_your_server"
vc.environment      = "SANDBOX"   // or "PRODUCTION"
vc.modalPresentationStyle = .fullScreen

vc.onPaymentComplete = { orderId in
    // Payment done — verify order status on your server using orderId
}
vc.onPaymentFailed = { message, orderId in
    // Show error to user
}

present(vc, animated: true)
```

**How the payment result comes back:**
The form POST includes a `platform` field (`iosx-c-2.3.7-x-m-x-x-i-26.0`). Cashfree uses this to redirect the WKWebView to a custom scheme:

The `WKNavigationDelegate` intercepts this, cancels the navigation, parses the JSON fragment, and fires the appropriate callback.

---

### Mode 2 — Merchant URL Integration (`CFMerchantWebViewController`)

Use this when you already have **your own website** (e.g. `https://yourstore.com/checkout`) that embeds the Cashfree JS SDK and calls `cashfree.checkout()` itself. The native app just opens that URL in a WebView — no order creation needed on the native side.

**Flow:**
1. Native app loads the merchant's checkout URL in a `WKWebView`
2. The merchant's page loads the Cashfree JS SDK and calls `cashfree.checkout()`
3. The Cashfree JS SDK detects it is running inside a native iOS WebView (via `window.webkit.messageHandlers`) and activates the native bridge automatically
4. UPI intent handling, app list, and payment completion all flow through the native bridge

```swift
let vc = CFMerchantWebViewController()
vc.merchantURL = "https://yourstore.com/checkout"
vc.modalPresentationStyle = .fullScreen

vc.onPaymentComplete = {
    // Payment done — verify order status on your server
}
vc.onPaymentFailed = { message in
    // Show error to user
}

present(vc, animated: true)
```

**What your web page must do:**
```html
<!-- 1. Load the Cashfree JS SDK -->
<script src="https://sdk.cashfree.com/js/v3/cashfree.js"></script>

<script>
  // 2. Initialize with your environment
  const cashfree = Cashfree({ mode: "production" }); // or "sandbox"

  // 3. Call checkout with payment_session_id from your server
  cashfree.checkout({
    paymentSessionId: "session_id_from_your_server",
    redirectTarget: "_self"
  });
</script>
```

**How the JS bridge registers:**
Native registers a `WKScriptMessageHandler` named `nativeProcess` on the `WKWebView` before loading any URL. This makes `window.webkit.messageHandlers.nativeProcess` available to every page loaded in that WebView — including your domain. The Cashfree JS SDK detects this object and switches to native bridge mode automatically. No extra configuration needed on the web side.

---

## JS Bridge Message Contract

Both modes use the same native bridge. These messages are sent by the Cashfree JS SDK to native:

| Direction | Message | Description |
|---|---|---|
| JS → Native | `"getAppList"` | Query which UPI apps are installed |
| Native → JS | `window.receiveAppList([{displayName, id, icon}])` | Return installed UPI apps |
| JS → Native | `"phonepe://pay?..."` (UPI deep link) | Open UPI app for payment |
| Native → JS | `verifyPaymentForiOS()` | Called before opening UPI app — starts JS-side verification |
| JS → Native | `"dismissLoader"` | Hide the native loading indicator |
| JS → Native | `"dismissWeb"` | Payment complete — dismiss the WebView |

> **Important:** `verifyPaymentForiOS()` must be called **before** `UIApplication.shared.open(upiURL)`. On Android this happens in `onActivityResult`. On iOS there is no equivalent, so the JS SDK handles verification itself when `verifyPaymentForiOS()` is called.

---

## Info.plist Setup (Required)

`canOpenURL()` only works for schemes declared in `LSApplicationQueriesSchemes`. Without this, the app list will always be empty and UPI app selection will not work.

Add to your `Info.plist`:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>tez</string>
    <string>phonepe</string>
    <string>paytmmp</string>
    <string>bhim</string>
    <string>credpay</string>
    <string>amazonpay</string>
    <string>whatsapp-consumer</string>
    <string>navipay</string>
    <string>mobikwik</string>
    <string>myairtel</string>
    <string>popclubapp</string>
    <string>super</string>
    <string>kiwi</string>
    <string>simplypayupi</string>
</array>
```

---

## Security Note

The sample app calls the Cashfree sandbox API directly from the device to create test orders. **Never do this in production.** Order creation must happen on your server — the mobile app should only receive the `payment_session_id` and pass it to the checkout controller. Exposing your API credentials in a mobile app is a security risk.

---

## Support

For integration questions, refer to the [Cashfree developer documentation](https://docs.cashfree.com).
