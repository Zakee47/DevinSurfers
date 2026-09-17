import SceneKit
import UIKit

final class Collectible {
    enum Kind {
        case token
        case powerUp(PowerUpKind)
    }

    let kind: Kind
    let node = SCNNode()
    var collected = false

    init(kind: Kind) {
        self.kind = kind
        build()
    }

    private func build() {
        switch kind {
        case .token:
            let gold = SCNMaterial()
            gold.diffuse.contents = UIColor(red: 0.961, green: 0.773, blue: 0.094, alpha: 1) // #F5C518
            gold.metalness.contents = 0.8
            gold.roughness.contents = 0.3
            gold.lightingModel = .physicallyBased
            let coin = SCNCylinder(radius: 0.3, height: 0.08)
            coin.materials = [gold]
            let c = SCNNode(geometry: coin)
            c.rotation = SCNVector4(0, 0, 1, Float.pi / 2) // upright, facing +z
            node.addChildNode(c)
            let t = SCNText(string: "ACU", extrusionDepth: 0.01)
            t.font = UIFont.boldSystemFont(ofSize: 0.18)
            t.flatness = 0.05
            let dark = SCNMaterial()
            dark.diffuse.contents = UIColor(red: 0.4, green: 0.3, blue: 0.05, alpha: 1)
            t.materials = [dark]
            let tn = SCNNode(geometry: t)
            let (minB, maxB) = tn.boundingBox
            tn.pivot = SCNMatrix4MakeTranslation((maxB.x - minB.x) / 2 + minB.x, (maxB.y - minB.y) / 2 + minB.y, 0)
            tn.position = SCNVector3(-0.05, 0, 0)
            tn.rotation = SCNVector4(0, 1, 0, Float.pi / 2)
            c.addChildNode(tn)
            node.position.y = 0.6
        case .powerUp(let p):
            let shape: SCNGeometry
            let color: UIColor
            switch p {
            case .magnet: shape = SCNTorus(ringRadius: 0.25, pipeRadius: 0.1); color = .systemRed
            case .jetpack: shape = SCNBox(width: 0.4, height: 0.55, length: 0.25, chamferRadius: 0.06); color = .systemOrange
            case .superSneakers: shape = SCNBox(width: 0.5, height: 0.2, length: 0.3, chamferRadius: 0.08); color = .systemGreen
            case .multiplier2x: shape = SCNSphere(radius: 0.3); color = .systemPurple
            case .hoverboardPickup: shape = SCNBox(width: 0.7, height: 0.08, length: 0.3, chamferRadius: 0.04); color = .systemTeal
            }
            let m = SCNMaterial()
            m.diffuse.contents = color
            m.emission.contents = color.withAlphaComponent(0.4)
            m.lightingModel = .physicallyBased
            shape.materials = [m]
            let n = SCNNode(geometry: shape)
            node.addChildNode(n)
            node.position.y = 1.0
        }
    }

    func update(dt: TimeInterval) {
        node.rotation = SCNVector4(0, 1, 0, node.rotation.w + Float(dt * 3))
    }
}
