import SceneKit
import UIKit

enum ObstacleKind {
    case lowBarrier   // jump over
    case highBarrier  // roll under (overhead sign)
    case fullBarrier  // must change lane
    case train        // stationary, can run on top
    case movingTrain  // approaches faster; cannot climb
    case signpost     // "AI SLOP" billboard -> fullBarrier collision
}

final class Obstacle {
    let kind: ObstacleKind
    let node = SCNNode()
    var lane: Int = 1
    var length: Float = 1.0
    // AABB half extents (x width, y from node.position.y)
    var halfW: Float = 0.9
    var minY: Float = 0
    var maxY: Float = 1
    var trainTopHeight: Float = 0
    var scored = false   // for train-dodge mission counting

    init(kind: ObstacleKind) {
        self.kind = kind
        build()
    }

    static func sharedMaterial(_ key: String, _ make: () -> SCNMaterial) -> SCNMaterial {
        if let m = materialCache[key] { return m }
        let m = make()
        materialCache[key] = m
        return m
    }
    private static var materialCache: [String: SCNMaterial] = [:]

    static func mat(_ color: UIColor, roughness: CGFloat = 0.8, emissive: UIColor? = nil) -> SCNMaterial {
        let key = "\(color.description)_\(roughness)_\(emissive?.description ?? "")"
        return sharedMaterial(key) {
            let m = SCNMaterial()
            m.diffuse.contents = color
            m.roughness.contents = roughness
            m.lightingModel = .physicallyBased
            if let e = emissive { m.emission.contents = e }
            return m
        }
    }

    static func aiSlopText(fontSize: CGFloat = 0.35, text: String = "AI SLOP") -> SCNNode {
        let t = SCNText(string: text, extrusionDepth: 0.02)
        t.font = UIFont.boldSystemFont(ofSize: fontSize)
        t.flatness = 0.1
        let red = SCNMaterial()
        red.diffuse.contents = UIColor.red
        red.lightingModel = .blinn
        t.materials = [red]
        let n = SCNNode(geometry: t)
        let (minB, maxB) = n.boundingBox
        n.pivot = SCNMatrix4MakeTranslation((maxB.x - minB.x) / 2 + minB.x, (maxB.y - minB.y) / 2 + minB.y, 0)
        return n
    }

    private func build() {
        switch kind {
        case .lowBarrier:
            // striped hurdle bar on two posts
            halfW = 1.0; minY = 0; maxY = 0.9; length = 0.4
            let white = Self.mat(.white)
            let red = Self.mat(.red)
            for i in 0..<3 {
                let seg = SCNBox(width: 0.67, height: 0.22, length: 0.1, chamferRadius: 0)
                seg.materials = [i % 2 == 0 ? red : white]
                let s = SCNNode(geometry: seg)
                s.position = SCNVector3(-0.67 + Float(i) * 0.67, 0.75, 0)
                node.addChildNode(s)
            }
            for side: Float in [-1, 1] {
                let post = SCNBox(width: 0.08, height: 0.9, length: 0.08, chamferRadius: 0)
                post.materials = [Self.mat(.darkGray)]
                let p = SCNNode(geometry: post)
                p.position = SCNVector3(0.95 * side, 0.45, 0)
                node.addChildNode(p)
            }
        case .highBarrier:
            // overhead hanging sign; roll under. Gap below ~1.1
            halfW = 1.0; minY = 1.1; maxY = 2.6; length = 0.3
            let panel = SCNBox(width: 2.0, height: 1.0, length: 0.1, chamferRadius: 0.02)
            panel.materials = [Self.mat(UIColor(white: 0.95, alpha: 1))]
            let p = SCNNode(geometry: panel)
            p.position = SCNVector3(0, 1.8, 0)
            node.addChildNode(p)
            let label = Self.aiSlopText(fontSize: 0.4)
            label.position = SCNVector3(0, 1.8, 0.08)
            node.addChildNode(label)
            for side: Float in [-1, 1] {
                let post = SCNBox(width: 0.08, height: 2.6, length: 0.08, chamferRadius: 0)
                post.materials = [Self.mat(.darkGray)]
                let po = SCNNode(geometry: post)
                po.position = SCNVector3(1.0 * side, 1.3, 0)
                node.addChildNode(po)
            }
        case .fullBarrier:
            // wooden fence filling the lane
            halfW = 1.0; minY = 0; maxY = 1.8; length = 0.3
            let wood = Self.mat(UIColor(red: 0.55, green: 0.35, blue: 0.2, alpha: 1))
            for i in 0..<4 {
                let plank = SCNBox(width: 2.0, height: 0.35, length: 0.12, chamferRadius: 0.02)
                plank.materials = [wood]
                let pl = SCNNode(geometry: plank)
                pl.position = SCNVector3(0, 0.3 + Float(i) * 0.42, 0)
                node.addChildNode(pl)
            }
        case .train:
            length = Float.random(in: 12...24)
            halfW = 1.0; minY = 0; maxY = 3.0; trainTopHeight = 3.0
            let colors: [UIColor] = [.systemYellow, .systemBlue, .systemRed]
            let bodyMat = Self.mat(colors.randomElement()!)
            let body = SCNBox(width: 2.0, height: 2.6, length: CGFloat(length), chamferRadius: 0.15)
            body.materials = [bodyMat]
            let b = SCNNode(geometry: body)
            b.position = SCNVector3(0, 1.4, 0)
            node.addChildNode(b)
            // windows strip
            let win = SCNBox(width: 2.02, height: 0.5, length: CGFloat(length * 0.9), chamferRadius: 0.02)
            win.materials = [Self.mat(UIColor(white: 0.15, alpha: 1), roughness: 0.2)]
            let w = SCNNode(geometry: win)
            w.position = SCNVector3(0, 2.2, 0)
            node.addChildNode(w)
            // roof
            let roof = SCNBox(width: 1.9, height: 0.15, length: CGFloat(length * 0.95), chamferRadius: 0.05)
            roof.materials = [Self.mat(.darkGray)]
            let r = SCNNode(geometry: roof)
            r.position = SCNVector3(0, 2.75, 0)
            node.addChildNode(r)
            // AI SLOP label on front
            let label = Self.aiSlopText(fontSize: 0.35)
            label.position = SCNVector3(0, 1.6, length / 2 + 0.05)
            node.addChildNode(label)
        case .movingTrain:
            length = 20
            halfW = 1.0; minY = 0; maxY = 3.0
            let body = SCNBox(width: 2.0, height: 2.6, length: CGFloat(length), chamferRadius: 0.15)
            body.materials = [Self.mat(UIColor(white: 0.25, alpha: 1))]
            let b = SCNNode(geometry: body)
            b.position = SCNVector3(0, 1.4, 0)
            node.addChildNode(b)
            // headlight
            let light = SCNSphere(radius: 0.2)
            light.materials = [Self.mat(.white, roughness: 0.1, emissive: .yellow)]
            let l = SCNNode(geometry: light)
            l.position = SCNVector3(0, 1.4, length / 2 + 0.1)
            node.addChildNode(l)
            let label = Self.aiSlopText(fontSize: 0.35)
            label.position = SCNVector3(0, 2.0, length / 2 + 0.05)
            node.addChildNode(label)
        case .signpost:
            // AI SLOP billboard on posts: fullBarrier collision
            halfW = 1.0; minY = 0; maxY = 2.4; length = 0.4
            let panel = SCNBox(width: 2.0, height: 1.2, length: 0.1, chamferRadius: 0.02)
            panel.materials = [Self.mat(.white)]
            let p = SCNNode(geometry: panel)
            p.position = SCNVector3(0, 1.5, 0)
            node.addChildNode(p)
            let label = Self.aiSlopText(fontSize: 0.42)
            label.position = SCNVector3(0, 1.5, 0.08)
            node.addChildNode(label)
            for side: Float in [-1, 1] {
                let post = SCNBox(width: 0.08, height: 1.0, length: 0.08, chamferRadius: 0)
                post.materials = [Self.mat(.darkGray)]
                let po = SCNNode(geometry: post)
                po.position = SCNVector3(0.8 * side, 0.5, 0)
                node.addChildNode(po)
            }
        }
    }
}
