import SwiftUI
import SpriteKit
import UIKit

@main
struct KaidityaApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .ignoresSafeArea()
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}

/// SwiftUI wrapper around a UIKit game view controller so we control the
/// responder chain (needed for hardware-keyboard input).
struct GameView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> GameViewController { GameViewController() }
    func updateUIViewController(_ vc: GameViewController, context: Context) {}
}

/// An SKView that can become first responder and forwards key presses to the scene.
final class KeyboardSKView: SKView {
    override var canBecomeFirstResponder: Bool { true }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if let s = scene { s.pressesBegan(presses, with: event) }
        else { super.pressesBegan(presses, with: event) }
    }
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if let s = scene { s.pressesEnded(presses, with: event) }
        else { super.pressesEnded(presses, with: event) }
    }
    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if let s = scene { s.pressesCancelled(presses, with: event) }
        else { super.pressesCancelled(presses, with: event) }
    }
}

final class GameViewController: UIViewController {
    override var canBecomeFirstResponder: Bool { true }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    override func loadView() {
        let v = KeyboardSKView(frame: UIScreen.main.bounds)
        v.ignoresSiblingOrder = true
        view = v
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let skView = view as! KeyboardSKView
        let scene = GameScene(size: skView.bounds.size == .zero ? CGSize(width: 1334, height: 750) : skView.bounds.size)
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.becomeFirstResponder()
    }
}
