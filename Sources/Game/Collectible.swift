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
    private var bobT: TimeInterval = .random(in: 0...6)
    private var baseY: Float?

    init(kind: Kind) {
        self.kind = kind
        build()
    }

    private static var goldMat: SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(red: 0.961, green: 0.773, blue: 0.094, alpha: 1)  // #F5C518
        m.metalness.contents = 0.9
        m.roughness.contents = 0.25
        m.emission.contents = UIColor(red: 0.961, green: 0.773, blue: 0.094, alpha: 0.35)
        m.lightingModel = .physicallyBased
        return m
    }

    private func build() {
        switch kind {
        case .token:
            // SS coin: thin disc on edge, faces camera (faces ±z), spins around Y
            let coin = SCNCylinder(radius: 0.32, height: 0.07)
            coin.materials = [Self.goldMat]
            let c = SCNNode(geometry: coin)
            c.rotation = SCNVector4(1, 0, 0, Float.pi / 2)
            node.addChildNode(c)
            let t = SCNText(string: "ACU", extrusionDepth: 0.005)
            t.font = UIFont.boldSystemFont(ofSize: 0.18)
            t.flatness = 0.05
            let dark = SCNMaterial()
            dark.diffuse.contents = UIColor(red: 0.5, green: 0.38, blue: 0.06, alpha: 1)
            t.materials = [dark]
            let tn = SCNNode(geometry: t)
            let (minB, maxB) = tn.boundingBox
            tn.pivot = SCNMatrix4MakeTranslation((maxB.x - minB.x) / 2 + minB.x, (maxB.y - minB.y) / 2 + minB.y, 0)
            tn.position = SCNVector3(0, 0, 0.045)
            c.addChildNode(tn)
            node.position.y = 0.6
        case .powerUp(let p):
            // glowing pedestal
            let ped = SCNCylinder(radius: 0.45, height: 0.06)
            let pm = SCNMaterial()
            pm.diffuse.contents = UIColor.white.withAlphaComponent(0.9)
            pm.emission.contents = UIColor.white.withAlphaComponent(0.6)
            ped.materials = [pm]
            let pn = SCNNode(geometry: ped)
            pn.position = SCNVector3(0, -0.55, 0)
            node.addChildNode(pn)

            let icon = SCNNode()
            switch p {
            case .magnet:
                // red U-magnet: two red bars + gray tips
                let red = Obstacle.mat(.systemRed, roughness: 0.4)
                let gray = Obstacle.mat(UIColor(white: 0.6, alpha: 1), roughness: 0.3, metal: 0.7)
                for side: Float in [-1, 1] {
                    let bar = SCNBox(width: 0.12, height: 0.45, length: 0.12, chamferRadius: 0.02)
                    bar.materials = [red]
                    let b = SCNNode(geometry: bar)
                    b.position = SCNVector3(0.14 * side, 0.05, 0)
                    icon.addChildNode(b)
                    let tip = SCNBox(width: 0.14, height: 0.12, length: 0.14, chamferRadius: 0.01)
                    tip.materials = [gray]
                    let tp = SCNNode(geometry: tip)
                    tp.position = SCNVector3(0.14 * side, -0.2, 0)
                    icon.addChildNode(tp)
                }
                let arc = SCNTorus(ringRadius: 0.14, pipeRadius: 0.07)
                arc.materials = [red]
                let a = SCNNode(geometry: arc)
                a.position = SCNVector3(0, 0.27, 0)
                icon.addChildNode(a)
            case .jetpack:
                // blue twin tanks
                let blue = Obstacle.mat(UIColor(red: 0.122, green: 0.435, blue: 0.910, alpha: 1), roughness: 0.3, metal: 0.5)
                for side: Float in [-1, 1] {
                    let tank = SCNCylinder(radius: 0.11, height: 0.5)
                    tank.materials = [blue]
                    let t = SCNNode(geometry: tank)
                    t.position = SCNVector3(0.14 * side, 0.05, 0)
                    icon.addChildNode(t)
                }
            case .superSneakers:
                // white/orange shoe box
                let box = SCNBox(width: 0.5, height: 0.2, length: 0.3, chamferRadius: 0.06)
                box.materials = [Obstacle.mat(.systemOrange)]
                let b = SCNNode(geometry: box)
                icon.addChildNode(b)
                let lid = SCNBox(width: 0.54, height: 0.08, length: 0.34, chamferRadius: 0.02)
                lid.materials = [Obstacle.mat(.white)]
                let l = SCNNode(geometry: lid)
                l.position = SCNVector3(0, 0.13, 0)
                icon.addChildNode(l)
            case .multiplier2x:
                let label = Obstacle.textNode("2X", fontSize: 0.5, color: UIColor(red: 0.961, green: 0.773, blue: 0.094, alpha: 1))
                icon.addChildNode(label)
            case .hoverboardPickup:
                let board = SCNBox(width: 0.7, height: 0.07, length: 0.28, chamferRadius: 0.05)
                board.materials = [Obstacle.mat(.systemTeal, emissive: UIColor.systemTeal.withAlphaComponent(0.5))]
                let b = SCNNode(geometry: board)
                icon.addChildNode(b)
            }
            icon.position = SCNVector3(0, 0.1, 0)
            node.addChildNode(icon)
            node.position.y = 1.0
        }
    }

    func update(dt: TimeInterval) {
        bobT += dt
        let baseY = self.baseY ?? node.position.y
        self.baseY = baseY
        switch kind {
        case .token:
            node.rotation = SCNVector4(0, 1, 0, node.rotation.w + Float(dt * 4))
            node.position.y = baseY + Float(sin(bobT * 2.5)) * 0.08
        case .powerUp:
            node.rotation = SCNVector4(0, 1, 0, node.rotation.w + Float(dt * 1.5))
            node.position.y = baseY + Float(sin(bobT * 2)) * 0.12
        }
    }
}
