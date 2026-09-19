import SceneKit
import UIKit

final class Chaser {
    let node = SCNNode()
    private(set) var active = false
    private var timer: TimeInterval = 0
    private var duration: TimeInterval = 6
    private var drone: SCNNode?

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
        let label = Obstacle.textNode("SLOP", fontSize: 0.3, color: .red)
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

        // little slop drone hovering alongside
        let dr = SCNNode()
        let dbody = SCNSphere(radius: 0.18)
        let dm = SCNMaterial()
        dm.diffuse.contents = UIColor(white: 0.5, alpha: 1)
        dm.metalness.contents = 0.6
        dbody.materials = [dm]
        let db = SCNNode(geometry: dbody)
        dr.addChildNode(db)
        let deye = SCNSphere(radius: 0.05)
        deye.materials = [em]
        let de = SCNNode(geometry: deye)
        de.position = SCNVector3(0, 0, 0.17)
        dr.addChildNode(de)
        dr.position = SCNVector3(1.1, 1.6, 0)
        node.addChildNode(dr)
        drone = dr

        // keep it small so it doesn't block the screen (~1.5 tall)
        node.scale = SCNVector3(0.75, 0.75, 0.75)
        node.isHidden = true
    }

    private var isIntro = false

    func trigger(duration: TimeInterval = 6, intro: Bool = false) {
        active = true
        timer = 0
        self.duration = duration
        isIntro = intro
        node.isHidden = false
        node.opacity = 1
    }

    func dismiss() {
        active = false
        node.isHidden = true
    }

    /// moves chaser directly onto the player (death grab)
    func grabAt(playerX: Float) {
        active = true
        timer = 0
        duration = .infinity
        node.isHidden = false
        node.opacity = 1
        node.position = SCNVector3(playerX, 0, 1.0)
    }

    // follows the player from behind; offset x opposite to camera lag
    func update(dt: TimeInterval, playerX: Float, camX: Float) {
        guard active else { return }
        timer += dt
        let offsetSide: Float = playerX > camX + 0.05 ? 1 : (playerX < camX - 0.05 ? -1 : 1)
        let targetX = playerX + 0.6 * offsetSide
        node.position.x += (targetX - node.position.x) * Float(min(1, dt * 8))
        if isIntro {
            // drop back from z=2.4 to z=4 while fading over the intro duration
            let t = Float(min(1, timer / duration))
            node.position.z = 2.4 + t * 1.6
            node.opacity = CGFloat(1 - t * t)
        } else {
            node.position.z = 2.4 // just behind player, in front of camera
        }
        drone?.position.y = 1.6 + Float(sin(timer * 5)) * 0.15
        if !isIntro, timer > duration - 1 {
            node.opacity = CGFloat(max(0, 1 - Float(timer - (duration - 1))))
        }
        if timer >= duration { dismiss() }
    }
}
