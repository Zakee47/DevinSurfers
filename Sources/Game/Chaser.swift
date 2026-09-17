import SceneKit
import UIKit

final class Chaser {
    let node = SCNNode()
    private(set) var active = false
    private var timer: TimeInterval = 0
    let duration: TimeInterval = 6

    init() {
        let gray = SCNMaterial()
        gray.diffuse.contents = UIColor(white: 0.45, alpha: 1)
        gray.metalness.contents = 0.6
        gray.roughness.contents = 0.5
        gray.lightingModel = .physicallyBased

        let body = SCNBox(width: 0.8, height: 1.0, length: 0.5, chamferRadius: 0.05)
        body.materials = [gray]
        let b = SCNNode(geometry: body)
        b.position = SCNVector3(0, 1.0, 0)
        node.addChildNode(b)

        let head = SCNBox(width: 0.6, height: 0.5, length: 0.5, chamferRadius: 0.05)
        head.materials = [gray]
        let h = SCNNode(geometry: head)
        h.position = SCNVector3(0, 1.75, 0)
        node.addChildNode(h)

        // red glowing eye
        let eye = SCNSphere(radius: 0.1)
        let em = SCNMaterial()
        em.diffuse.contents = UIColor.red
        em.emission.contents = UIColor.red
        eye.materials = [em]
        let e = SCNNode(geometry: eye)
        e.position = SCNVector3(0, 1.78, 0.26)
        node.addChildNode(e)

        // SLOP label
        let label = Obstacle.aiSlopText(fontSize: 0.3, text: "SLOP")
        label.position = SCNVector3(0, 1.0, 0.26)
        node.addChildNode(label)

        // legs
        for side: Float in [-1, 1] {
            let leg = SCNBox(width: 0.2, height: 0.6, length: 0.25, chamferRadius: 0.03)
            leg.materials = [gray]
            let l = SCNNode(geometry: leg)
            l.position = SCNVector3(0.22 * side, 0.3, 0)
            node.addChildNode(l)
        }

        node.isHidden = true
    }

    func trigger() {
        active = true
        timer = 0
        node.isHidden = false
        node.opacity = 1
    }

    func dismiss() {
        active = false
        node.isHidden = true
    }

    // follows the player from behind
    func update(dt: TimeInterval, playerX: Float) {
        guard active else { return }
        timer += dt
        node.position.x += (playerX - node.position.x) * Float(min(1, dt * 8))
        node.position.z = 2.2 // just behind player
        if timer > duration - 1 {
            node.opacity = max(0, 1 - (timer - (duration - 1)))
        }
        if timer >= duration { dismiss() }
    }
}
