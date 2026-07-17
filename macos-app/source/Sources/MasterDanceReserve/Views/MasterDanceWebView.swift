import SwiftUI
import WebKit

struct MasterDanceWebView: NSViewRepresentable {
    func makeCoordinator() -> NativeBridge {
        NativeBridge()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: NativeBridge.messageHandlerName)
        configuration.userContentController = userContentController
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        context.coordinator.attach(webView: webView)

        let indexURL = AppPaths.webIndexURL
        webView.loadFileURL(indexURL, allowingReadAccessTo: indexURL.deletingLastPathComponent())
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: WKWebView, coordinator: NativeBridge) {
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: NativeBridge.messageHandlerName)
    }
}
