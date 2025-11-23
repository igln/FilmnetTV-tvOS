import SwiftUI

struct ContentView: View {
    @StateObject private var input = RemoteInput()
    @State private var scrollOffset: CGPoint = .zero
    @State private var keyboardText: String = ""
    
    // The URL to load
    private let filmnetURL = URL(string: "https://tv.filmnet.ir")!
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // 1. The Web View
                WebView(
                    url: filmnetURL,
                    scrollOffset: $scrollOffset,
                    triggerClick: $input.isClicking,
                    triggerBack: $input.triggerBack,
                    cursorPosition: $input.cursorPosition,
                    screenSize: geometry.size
                )
                .ignoresSafeArea()
                
                // 2. The Cursor
                Circle()
                    .fill(Color.red.opacity(0.7))
                    .frame(width: 20, height: 20)
                    .shadow(radius: 2)
                    .position(input.cursorPosition)
                    .allowsHitTesting(false) // Let events pass through (visually)
            }
            .onAppear {
                input.updateScreenSize(geometry.size)
            }
            .onChange(of: geometry.size) { newSize in
                input.updateScreenSize(newSize)
            }
            // Keyboard Overlay
            .alert("Enter Text", isPresented: $input.showKeyboard) {
                TextField("Type here...", text: $keyboardText)
                Button("Submit") {
                    // Inject text
                    injectText(keyboardText)
                    keyboardText = ""
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
    
    private func injectText(_ text: String) {
        // We need to tell the WebView to insert this text
        // But WebView struct is not directly accessible here as an object instance.
        // We need to send a command via binding or notification.
        // Let's add a binding for "textToInject" to WebView.
        // Actually, simpler: update the `RemoteInput` to hold the text, pass it to WebView.
        NotificationCenter.default.post(name: NSNotification.Name("InjectText"), object: text)
    }
}
