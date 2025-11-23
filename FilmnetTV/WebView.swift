import SwiftUI

// Define a protocol to interact with the dynamically loaded WKWebView
@objc protocol WebViewExport {
    func load(_ request: URLRequest) -> AnyObject?
    func goBack() -> AnyObject?
    var canGoBack: Bool { get }
    var scrollView: UIScrollView { get }
    var customUserAgent: String? { get set }
    var navigationDelegate: Any? { get set }
    func evaluateJavaScript(_ javaScriptString: String, completionHandler: ((Any?, Error?) -> Void)?)
}

struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var scrollOffset: CGPoint
    @Binding var triggerClick: Bool
    @Binding var triggerBack: Bool
    @Binding var cursorPosition: CGPoint
    let screenSize: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIView {
        // Listen for text injection
        NotificationCenter.default.addObserver(forName: NSNotification.Name("InjectText"), object: nil, queue: .main) { notif in
            if let text = notif.object as? String, let webView = context.coordinator.lastWebView {
                self.injectText(text, into: webView)
            }
        }

        // 1. Dynamically load WebKit
        let bundlePath = "/System/Library/Frameworks/WebKit.framework"
        guard let bundle = Bundle(path: bundlePath), bundle.load() else {
            print("Failed to load WebKit bundle")
            return UIView()
        }

        // 2. Get WKWebView class
        guard let wkWebViewClass = NSClassFromString("WKWebView") as? NSObject.Type else {
            print("WKWebView class not found")
            return UIView()
        }

        // 4. Initialize WebView
        // Use standard init() which is safer than performSelector("alloc") in Swift.
        guard let webView = wkWebViewClass.init() as? UIView else {
             print("Failed to init WKWebView")
             return UIView()
        }
        
        // 5. Configure
        webView.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15", forKey: "customUserAgent")
        webView.setValue(context.coordinator, forKey: "navigationDelegate")
        
        // Disable default keyboard handling if possible to avoid analytics crash
        // This is hard without private APIs. 
        
        // 6. Load URL
        let request = URLRequest(url: url)
        let loadSelector = NSSelectorFromString("loadRequest:")
        _ = webView.perform(loadSelector, with: request)

        context.coordinator.lastWebView = webView
        return webView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Check if it's actually a webview
        guard let webViewClass = NSClassFromString("WKWebView"), uiView.isKind(of: webViewClass) else { return }

        // Handle Click Trigger
        if triggerClick {
            DispatchQueue.main.async {
                triggerClick = false
                simulateClick(in: uiView, at: cursorPosition)
            }
        }
        
        // Handle Back Trigger
        if triggerBack {
            DispatchQueue.main.async {
                triggerBack = false
                // canGoBack check
                if let canGoBack = uiView.value(forKey: "canGoBack") as? Bool, canGoBack {
                    let goBackSel = NSSelectorFromString("goBack")
                    _ = uiView.perform(goBackSel)
                }
            }
        }
    }
    
    private func simulateClick(in webView: UIView, at point: CGPoint) {
        let js = """
        (function() {
            var x = \(point.x);
            var y = \(point.y);
            var el = document.elementFromPoint(x, y);
            if (el) {
                var ev = new MouseEvent('click', {
                    'view': window,
                    'bubbles': true,
                    'cancelable': true,
                    'clientX': x,
                    'clientY': y
                });
                el.dispatchEvent(ev);
                if (typeof el.click === 'function') { el.click(); }
                if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') { el.focus(); }
            }
        })();
        """
        
        // evaluateJavaScript:completionHandler:
        let sel = NSSelectorFromString("evaluateJavaScript:completionHandler:")
        // This is tricky with performSelector because of the completion block.
        // A safer KVC approach or unsafeBitCast might be needed, 
        // OR just define a helper in ObjC. 
        // For pure Swift without bridging header, we can try `perform` but block arguments are hard.
        // Fallback: Just fire and forget if possible?
        
        // Actually, `evaluateJavaScript:completionHandler:` takes a block. 
        // `performSelector` cannot handle blocks easily.
        
        // Alternative: Use `callJavaScript` via KeyValue coding? No.
        
        // Workaround: We define a closure and cast it to the expected block type?
        // It's hard in pure Swift.
        
        // Simplified for now: We might skip JS evaluation if we can't invoke it easily,
        // BUT clicking is essential.
        
        // Let's try to cast the view to an AnyObject that we "know" has the method?
        // Swift's dynamic dispatch might handle it if we declare the method in a protocol 
        // marked @objc, provided the underlying class implements it.
        
        if let dynamicWebView = webView as? WebViewExport {
             dynamicWebView.evaluateJavaScript(js, completionHandler: nil)
        } else {
            // Try raw perform with nil completion?
            // performSelector only supports objects. A block is an object?
            // passing nil as the second argument might work if the selector allows it.
            _ = webView.perform(sel, with: js, with: nil)
        }
    }

    private func injectText(_ text: String, into webView: UIView) {
        let safeText = text.replacingOccurrences(of: "'", with: "\\'")
        let js = """
        (function() {
            var el = document.activeElement;
            if (el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA')) {
                el.value = '\(safeText)';
                el.dispatchEvent(new Event('input', { bubbles: true }));
                el.dispatchEvent(new Event('change', { bubbles: true }));
            }
        })();
        """
        
        if let dynamicWebView = webView as? WebViewExport {
             dynamicWebView.evaluateJavaScript(js, completionHandler: nil)
        } else {
             let sel = NSSelectorFromString("evaluateJavaScript:completionHandler:")
             _ = webView.perform(sel, with: js, with: nil)
        }
    }

    class Coordinator: NSObject {
        var parent: WebView
        weak var lastWebView: UIView?

        init(_ parent: WebView) {
            self.parent = parent
        }

        
        // We need to implement WKNavigationDelegate methods loosely
        // Since we can't import WebKit, we can't conform to WKNavigationDelegate officially.
        // But the runtime doesn't check the protocol conformance at compile time.
        // We just need to implement the delegate methods with @objc
        
        @objc func webView(_ webView: Any, didFinishNavigation navigation: Any!) {
            print("Finished loading (Dynamic)")
        }
    }
}
