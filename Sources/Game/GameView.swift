import SwiftUI
import SceneKit
import UIKit

struct GameView: View {
    @EnvironmentObject var state: GameState

    var body: some View {
        ZStack {
            SceneViewRepresentable(state: state)
                .ignoresSafeArea()
            HUDView(onHoverboardTap: { state.hoverboardRequest = true })
        }
    }
}

final class KeyCommandViewController: UIViewController {
    var scene: GameScene?

    override var canBecomeFirstResponder: Bool { true }

    override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(left)),
            UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(right)),
            UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(up)),
            UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(down)),
            UIKeyCommand(input: " ", modifierFlags: [], action: #selector(space)),
            UIKeyCommand(input: "p", modifierFlags: [], action: #selector(pause)),
        ]
    }

    @objc func left() { scene?.swipeLeft() }
    @objc func right() { scene?.swipeRight() }
    @objc func up() { scene?.swipeUp() }
    @objc func down() { scene?.swipeDown() }
    @objc func space() { scene?.doubleTap() }
    @objc func pause() { scene?.tapPause() }
}

struct SceneViewRepresentable: UIViewRepresentable {
    let state: GameState

    func makeCoordinator() -> Coordinator { Coordinator(state: state) }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        let gs = context.coordinator.gameScene
        view.scene = gs.scene
        view.delegate = gs
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        view.antialiasingMode = .multisampling2X
        view.backgroundColor = .black

        // gestures
        let dirs: [UISwipeGestureRecognizer.Direction] = [.left, .right, .up, .down]
        for d in dirs {
            let g = UISwipeGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.swiped(_:)))
            g.direction = d
            view.addGestureRecognizer(g)
        }
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTapped(_:)))
        tap.numberOfTapsRequired = 2
        view.addGestureRecognizer(tap)

        // hidden key-command VC
        let kc = KeyCommandViewController()
        kc.scene = gs
        kc.view.isHidden = true
        if let window = view.window, let root = window.rootViewController {
            root.addChild(kc)
            view.addSubview(kc.view)
            kc.didMove(toParent: root)
        } else {
            // window not ready yet; attach on next runloop
            DispatchQueue.main.async {
                if let root = view.window?.rootViewController {
                    root.addChild(kc)
                    view.addSubview(kc.view)
                    kc.didMove(toParent: root)
                    view.becomeFirstResponder()
                }
            }
        }
        context.coordinator.keyVC = kc
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    final class Coordinator: NSObject {
        let gameScene: GameScene
        var keyVC: KeyCommandViewController?

        init(state: GameState) {
            gameScene = GameScene(state: state)
        }

        @objc func swiped(_ g: UISwipeGestureRecognizer) {
            switch g.direction {
            case .left: gameScene.swipeLeft()
            case .right: gameScene.swipeRight()
            case .up: gameScene.swipeUp()
            case .down: gameScene.swipeDown()
            default: break
            }
        }

        @objc func doubleTapped(_ g: UITapGestureRecognizer) {
            gameScene.doubleTap()
        }
    }
}
