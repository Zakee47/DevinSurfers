import SceneKit
import UIKit

enum ObstacleKind {
    case lowBarrier  // red/white striped bar — jump over
    case poleBarrier  // low pole fence variant — jump over
    case highBarrier  // green hanging sign — roll under
    case fullBarrier  // wooden fence / hazard board — must change lane
    case train  // stationary subway car — jumpable onto roof
    case flatbed  // low cargo car with ramp — run straight up
    case movingTrain  // approaches faster; cannot climb
    case signpost  // "AI SLOP" billboard -> fullBarrier collision
}

final class Obstacle {
    let kind: ObstacleKind
    let node = SCNNode()
    var lane: Int = 1
    var length: Float = 1.0
    // AABB half extents (x width, y from node.position.y)
    var halfW: Float = 1.1
    var minY: Float = 0
    var maxY: Float = 1
    var trainTopHeight: Float = 0
    var rampZone: Float = 0  // length of ramp portion at the near (+z) end
    var scored = false

    init(kind: ObstacleKind, length: Float? = nil) {
        self.kind = kind
        build(customLength: length)
    }

    func surfaceHeight(at worldZ: Float) -> Float {
        guard kind == .flatbed else { return trainTopHeight }
        let localZ = worldZ - node.worldPosition.z
        let progress = max(0, min(1, (length / 2 - localZ) / rampZone))
        return trainTopHeight * progress
    }

    // MARK: - Shared materials

    private static var materialCache: [String: SCNMaterial] = [:]
    static func mat(_ color: UIColor, roughness: CGFloat = 0.8, emissive: UIColor? = nil, metal: CGFloat = 0) -> SCNMaterial {
        let key = "\(color.description)_\(roughness)_\(emissive?.description ?? "")_\(metal)"
        if let m = materialCache[key] { return m }
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.roughness.contents = roughness
        if metal > 0 { m.metalness.contents = metal }
        m.lightingModel = .physicallyBased
        if let e = emissive { m.emission.contents = e }
        materialCache[key] = m
        return m
    }

    static func textNode(_ text: String, fontSize: CGFloat, color: UIColor) -> SCNNode {
        let t = SCNText(string: text, extrusionDepth: 0.02)
        t.font = UIFont.boldSystemFont(ofSize: fontSize)
        t.flatness = 0.1
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.lightingModel = .blinn
        t.materials = [m]
        let n = SCNNode(geometry: t)
        let (minB, maxB) = n.boundingBox
        n.pivot = SCNMatrix4MakeTranslation((maxB.x - minB.x) / 2 + minB.x, (maxB.y - minB.y) / 2 + minB.y, 0)
        return n
    }

    static func aiSlopText(fontSize: CGFloat = 0.35, text: String = "AI SLOP") -> SCNNode {
        textNode(text, fontSize: fontSize, color: .red)
    }

    private static let trainColors: [UIColor] = [
        UIColor(red: 0.949, green: 0.416, blue: 0.106, alpha: 1),  // orange #F26A1B
        UIColor(red: 0.122, green: 0.435, blue: 0.910, alpha: 1),  // blue #1F6FE8
        UIColor(red: 0.239, green: 0.710, blue: 0.290, alpha: 1),  // green #3DB54A
        UIColor(red: 0.886, green: 0.231, blue: 0.231, alpha: 1),  // red #E23B3B
        UIColor(red: 0.55, green: 0.30, blue: 0.80, alpha: 1),  // purple
    ]
    private static let stripeColors: [UIColor] = [.systemYellow, .white, .systemPink, .systemTeal]

    private func build(customLength: Float?) {
        switch kind {
        case .lowBarrier:
            // red/white striped bar on two gray posts — jump over
            halfW = 1.0
            minY = 0
            maxY = 0.85
            length = 0.4
            let white = Self.mat(.white)
            let red = Self.mat(UIColor(red: 0.886, green: 0.231, blue: 0.231, alpha: 1))
            for i in 0..<5 {
                let seg = SCNBox(width: 0.4, height: 0.28, length: 0.08, chamferRadius: 0.01)
                seg.materials = [i % 2 == 0 ? red : white]
                let s = SCNNode(geometry: seg)
                s.position = SCNVector3(-0.8 + Float(i) * 0.4, 0.7, 0)
                node.addChildNode(s)
            }
            for side: Float in [-1, 1] {
                let post = SCNBox(width: 0.08, height: 0.85, length: 0.08, chamferRadius: 0)
                post.materials = [Self.mat(UIColor(white: 0.45, alpha: 1), roughness: 0.4, metal: 0.6)]
                let p = SCNNode(geometry: post)
                p.position = SCNVector3(0.95 * side, 0.42, 0)
                node.addChildNode(p)
            }
        case .poleBarrier:
            // low pole fence — two horizontal bars on posts — jump over
            halfW = 1.0
            minY = 0
            maxY = 0.8
            length = 0.3
            let barMat = Self.mat(UIColor(red: 0.886, green: 0.231, blue: 0.231, alpha: 1))
            for y: Float in [0.45, 0.75] {
                let bar = SCNBox(width: 2.0, height: 0.1, length: 0.06, chamferRadius: 0.02)
                bar.materials = [barMat]
                let b = SCNNode(geometry: bar)
                b.position = SCNVector3(0, y, 0)
                node.addChildNode(b)
            }
            for side: Float in [-1, 1] {
                let post = SCNBox(width: 0.07, height: 0.8, length: 0.07, chamferRadius: 0)
                post.materials = [Self.mat(UIColor(white: 0.45, alpha: 1), roughness: 0.4, metal: 0.6)]
                let p = SCNNode(geometry: post)
                p.position = SCNVector3(0.95 * side, 0.4, 0)
                node.addChildNode(p)
            }
        case .highBarrier:
            // green square hanging "roll" sign — roll under; gap below ~1.15
            halfW = 1.0
            minY = 1.15
            maxY = 2.7
            length = 0.3
            let panel = SCNBox(width: 2.0, height: 1.15, length: 0.08, chamferRadius: 0.04)
            panel.materials = [Self.mat(UIColor(red: 0.239, green: 0.710, blue: 0.290, alpha: 1))]
            let p = SCNNode(geometry: panel)
            p.position = SCNVector3(0, 1.85, 0)
            node.addChildNode(p)
            // red strip with white AI SLOP
            let strip = SCNBox(width: 1.7, height: 0.4, length: 0.02, chamferRadius: 0.01)
            strip.materials = [Self.mat(UIColor(red: 0.886, green: 0.231, blue: 0.231, alpha: 1))]
            let s = SCNNode(geometry: strip)
            s.position = SCNVector3(0, 1.85, 0.05)
            node.addChildNode(s)
            let label = Self.textNode("AI SLOP", fontSize: 0.28, color: .white)
            label.position = SCNVector3(0, 1.85, 0.07)
            node.addChildNode(label)
            for side: Float in [-1, 1] {
                let post = SCNBox(width: 0.08, height: 2.7, length: 0.08, chamferRadius: 0)
                post.materials = [Self.mat(UIColor(white: 0.45, alpha: 1), roughness: 0.4, metal: 0.6)]
                let po = SCNNode(geometry: post)
                po.position = SCNVector3(1.0 * side, 1.35, 0)
                node.addChildNode(po)
            }
        case .fullBarrier:
            // tall wooden fence with yellow/black hazard board — must change lane
            halfW = 1.0
            minY = 0
            maxY = 1.9
            length = 0.3
            let wood = Self.mat(UIColor(red: 0.55, green: 0.35, blue: 0.2, alpha: 1))
            for i in 0..<4 {
                let plank = SCNBox(width: 2.0, height: 0.38, length: 0.1, chamferRadius: 0.02)
                plank.materials = [wood]
                let pl = SCNNode(geometry: plank)
                pl.position = SCNVector3(0, 0.28 + Float(i) * 0.44, 0)
                node.addChildNode(pl)
            }
            // hazard board stripe
            let haz = SCNBox(width: 2.0, height: 0.3, length: 0.04, chamferRadius: 0)
            haz.materials = [Self.mat(.systemYellow)]
            let h = SCNNode(geometry: haz)
            h.position = SCNVector3(0, 1.55, 0.06)
            node.addChildNode(h)
            let label = Self.textNode("AI SLOP", fontSize: 0.2, color: .black)
            label.position = SCNVector3(0, 1.55, 0.09)
            node.addChildNode(label)
        case .train, .movingTrain:
            length = customLength ?? Float.random(in: 16...24)
            halfW = 1.15
            minY = 0
            maxY = 3.2
            trainTopHeight = 3.0
            let moving = kind == .movingTrain
            let bodyColor = moving ? UIColor(white: 0.22, alpha: 1) : Self.trainColors.randomElement()!
            let bodyMat = Self.mat(bodyColor)
            // main body
            let body = SCNBox(width: 2.4, height: 2.6, length: CGFloat(length), chamferRadius: 0.12)
            body.materials = [bodyMat]
            let b = SCNNode(geometry: body)
            b.position = SCNVector3(0, 1.7, 0)
            node.addChildNode(b)
            // rounded roof
            let roof = SCNCylinder(radius: 1.15, height: CGFloat(length * 0.96))
            roof.materials = [Self.mat(bodyColor.withAlphaComponent(0.9))]
            let r = SCNNode(geometry: roof)
            r.scale = SCNVector3(1, 1, 0.28)
            r.rotation = SCNVector4(1, 0, 0, Float.pi / 2)
            r.position = SCNVector3(0, 3.0, 0)
            node.addChildNode(r)
            // dark undercarriage + wheels
            let under = SCNBox(width: 2.2, height: 0.5, length: CGFloat(length * 0.95), chamferRadius: 0.05)
            under.materials = [Self.mat(UIColor(white: 0.12, alpha: 1))]
            let u = SCNNode(geometry: under)
            u.position = SCNVector3(0, 0.45, 0)
            node.addChildNode(u)
            let wheelMat = Self.mat(UIColor(white: 0.2, alpha: 1), roughness: 0.4, metal: 0.7)
            var wz = -length / 2 + 1.5
            while wz < length / 2 - 1 {
                for side: Float in [-1, 1] {
                    let wheel = SCNCylinder(radius: 0.3, height: 0.15)
                    wheel.materials = [wheelMat]
                    let w = SCNNode(geometry: wheel)
                    w.rotation = SCNVector4(0, 0, 1, Float.pi / 2)
                    w.position = SCNVector3(1.0 * side, 0.3, wz)
                    node.addChildNode(w)
                }
                wz += 4
            }
            // window strip (dark)
            let win = SCNBox(width: 2.42, height: 0.6, length: CGFloat(length * 0.85), chamferRadius: 0.03)
            win.materials = [Self.mat(UIColor(white: 0.12, alpha: 1), roughness: 0.15, metal: 0.4)]
            let w = SCNNode(geometry: win)
            w.position = SCNVector3(0, 2.35, 0)
            node.addChildNode(w)
            // graffiti stripe along the side
            let stripe = SCNBox(width: 2.43, height: 0.35, length: CGFloat(length * 0.9), chamferRadius: 0.02)
            stripe.materials = [Self.mat(Self.stripeColors.randomElement()!)]
            let st = SCNNode(geometry: stripe)
            st.position = SCNVector3(0, 1.15, 0)
            node.addChildNode(st)
            // AI SLOP graffiti on the side
            let sideLabel = Self.aiSlopText(fontSize: 0.4)
            sideLabel.position = SCNVector3(1.22, 1.15, 0)
            sideLabel.rotation = SCNVector4(0, 1, 0, Float.pi / 2)
            node.addChildNode(sideLabel)
            let sideLabel2 = Self.aiSlopText(fontSize: 0.4)
            sideLabel2.position = SCNVector3(-1.22, 1.15, 0)
            sideLabel2.rotation = SCNVector4(0, 1, 0, -Float.pi / 2)
            node.addChildNode(sideLabel2)
            // near end (+z faces player): yellow headlight panel
            let face = SCNBox(width: 2.2, height: 1.0, length: 0.05, chamferRadius: 0.02)
            face.materials = [Self.mat(.systemYellow)]
            let f = SCNNode(geometry: face)
            f.position = SCNVector3(0, 1.5, length / 2 + 0.03)
            node.addChildNode(f)
            let headMat = Self.mat(.white, roughness: 0.1, emissive: .yellow)
            for side: Float in [-1, 1] {
                let light = SCNSphere(radius: 0.18)
                light.materials = [headMat]
                let l = SCNNode(geometry: light)
                l.position = SCNVector3(0.7 * side, 1.5, length / 2 + 0.12)
                node.addChildNode(l)
            }
            let frontLabel = Self.textNode(
                moving ? "AI SLOP EXPRESS" : "AI SLOP",
                fontSize: moving ? 0.28 : 0.35,
                color: moving ? .red : .black)
            frontLabel.position = SCNVector3(0, 2.5, length / 2 + 0.05)
            node.addChildNode(frontLabel)
        case .flatbed:
            // low cargo car + ramp at the near (+z) end
            length = customLength ?? 14
            rampZone = 4
            halfW = 1.15
            minY = 0
            maxY = 1.4
            trainTopHeight = 1.4
            let deck = SCNBox(width: 2.4, height: 0.25, length: CGFloat(length - rampZone), chamferRadius: 0.03)
            deck.materials = [Self.mat(UIColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1))]
            let d = SCNNode(geometry: deck)
            d.position = SCNVector3(0, trainTopHeight - 0.125, -rampZone / 2)
            node.addChildNode(d)
            let under = SCNBox(width: 2.2, height: 0.9, length: CGFloat(length - rampZone), chamferRadius: 0.05)
            under.materials = [Self.mat(UIColor(white: 0.15, alpha: 1))]
            let u = SCNNode(geometry: under)
            u.position = SCNVector3(0, 0.65, -rampZone / 2)
            node.addChildNode(u)
            // ramp at +z end
            let rampLength = sqrt(rampZone * rampZone + trainTopHeight * trainTopHeight)
            let ramp = SCNBox(width: 2.4, height: 0.1, length: CGFloat(rampLength), chamferRadius: 0.02)
            ramp.materials = [Self.mat(UIColor(white: 0.5, alpha: 1), roughness: 0.4, metal: 0.5)]
            let rp = SCNNode(geometry: ramp)
            rp.position = SCNVector3(0, trainTopHeight / 2, length / 2 - rampZone / 2)
            rp.rotation = SCNVector4(1, 0, 0, atan2(trainTopHeight, rampZone))
            node.addChildNode(rp)
            // a couple of crates on the deck
            for i in 0..<2 {
                let crate = SCNBox(width: 0.8, height: 0.8, length: 0.8, chamferRadius: 0.03)
                crate.materials = [Self.mat(UIColor(red: 0.7, green: 0.5, blue: 0.25, alpha: 1))]
                let c = SCNNode(geometry: crate)
                c.position = SCNVector3(Float(i) * 0.9 - 0.45, 1.75, Float.random(in: -length / 4...length / 4))
                node.addChildNode(c)
            }
        case .signpost:
            // AI SLOP billboard on posts: fullBarrier collision
            halfW = 1.0
            minY = 0
            maxY = 2.4
            length = 0.4
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
