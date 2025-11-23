import SwiftUI
import GameController

class RemoteInput: ObservableObject {
    @Published var cursorPosition: CGPoint = .zero
    @Published var isClicking: Bool = false
    @Published var triggerBack: Bool = false
    @Published var showKeyboard: Bool = false // Trigger for text input
    @Published var textInput: String = ""
    
    private var screenSize: CGSize = .zero
    
    // Joystick State
    private var velocity: CGPoint = .zero
    private var displayLink: CADisplayLink?
    private var lastDpad: (x: Float, y: Float) = (0, 0)
    
    init() {
        setupControllerObserver()
        setupDisplayLink()
    }
    
    func updateScreenSize(_ size: CGSize) {
        self.screenSize = size
        if cursorPosition == .zero && size != .zero {
            cursorPosition = CGPoint(x: size.width / 2, y: size.height / 2)
        }
    }
    
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateCursor))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func updateCursor() {
        guard screenSize != .zero else { return }
        
        // Apply velocity based on last dpad value
        let rawX = CGFloat(lastDpad.x)
        let rawY = CGFloat(lastDpad.y)
        
        // Deadzone (Critical for drift)
        let deadzone: CGFloat = 0.1
        let activeX = abs(rawX) > deadzone ? rawX : 0
        let activeY = abs(rawY) > deadzone ? rawY : 0
        
        guard activeX != 0 || activeY != 0 else { return }
        
        // Non-linear speed curve (Quadratic)
        // Allows precision (slow) at low tilt, and speed at high tilt
        let baseSpeed: CGFloat = 20.0 // Pixels per frame
        let moveX = (activeX * abs(activeX)) * baseSpeed
        let moveY = -(activeY * abs(activeY)) * baseSpeed // Invert Y for screen coords
        
        var newX = cursorPosition.x + moveX
        var newY = cursorPosition.y + moveY
        
        // Clamp
        newX = max(0, min(screenSize.width, newX))
        newY = max(0, min(screenSize.height, newY))
        
        self.cursorPosition = CGPoint(x: newX, y: newY)
    }
    
    private func setupControllerObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(controllerDidConnect), name: .GCControllerDidConnect, object: nil)
        if let controller = GCController.controllers().first {
            configureController(controller)
        }
    }
    
    @objc private func controllerDidConnect(_ notification: Notification) {
        if let controller = notification.object as? GCController {
            configureController(controller)
        }
    }
    
    private func configureController(_ controller: GCController) {
        if let microGamepad = controller.microGamepad {
            microGamepad.reportsAbsoluteDpadValues = true
            microGamepad.allowsRotation = true
            
            // 1. Movement Handler (Just updates state, DisplayLink handles movement)
            microGamepad.dpad.valueChangedHandler = { [weak self] (dpad, xValue, yValue) in
                self?.lastDpad = (xValue, yValue)
            }
            
            // 2. Click Handler (Short press = Click, Long press = Keyboard)
            // We need to detect long press manually since buttonA doesn't have a generic "long press" handler
            // actually it does: valueChangedHandler gives us continuous updates on pressure.
            
            microGamepad.buttonA.valueChangedHandler = { [weak self] (button, value, pressed) in
                guard let self = self else { return }
                if pressed {
                    // Button Down
                    // Start timer for long press?
                    // For simplicity: Just click on release. 
                    // Or actually, let's use Play/Pause for Keyboard?
                    // Or Menu?
                    
                    // Let's use "Select" for click.
                    self.triggerClickAction()
                }
            }
            
            // 3. Back / Menu
            microGamepad.buttonX.valueChangedHandler = { [weak self] (button, value, pressed) in
                if pressed {
                    DispatchQueue.main.async { self?.triggerBack = true }
                }
            }
            
            // 4. Keyboard Trigger (Play/Pause Button)
            // buttonX is often Play/Pause on Siri Remote (depending on profile)
            // actually buttonA is Select. buttonX is Play/Pause usually.
            // Let's map Play/Pause to KEYBOARD.
            // And Menu is handled by system (exits app) or we can override `controller.controllerPausedHandler`
            
            controller.controllerPausedHandler = { [weak self] _ in
                // Menu button pressed
                // Use this for "Back" instead?
                DispatchQueue.main.async { self?.triggerBack = true }
            }
            
            // Play/Pause for Keyboard
             // Note: GCMicroGamepad buttonX/buttonY mapping varies. 
             // Usually:
             // buttonA = Touchpad Click
             // buttonX = Play/Pause
             
             // Let's try to map Play/Pause to show keyboard
             // Using the standard buttonX
             microGamepad.buttonX.valueChangedHandler = { [weak self] (button, value, pressed) in
                 if pressed {
                     DispatchQueue.main.async {
                         self?.showKeyboard = true
                     }
                 }
             }
        }
    }
    
    private func triggerClickAction() {
        DispatchQueue.main.async {
            self.isClicking = true
        }
    }
}
