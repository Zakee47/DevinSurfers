import SceneKit
import UIKit

final class Player {
    let node = SCNNode()      // root at lane position
    let bodyNode = SCNNode()  // visual body (bobs, squashes)
    private var tailNode: SCNNode?
    private var runTime: TimeInterval = 0
    private var armL: SCNNode?
    private var armR: SCNNode?
    private var legL: SCNNode?
    private var legR: SCNNode?
    private var shadowNode: SCNNode?
    private(set) var jetpackNode: SCNNode?
    private(set) var sneakersNode: SCNNode?

    // movement state
    var lane: Int = 1 // 0,1,2
    var laneX: Float { TrackManager.laneX(lane) }
    var visualY: Float = 0     // jump height above ground
    var isJumping = false
    var isRolling = false
    var isStumbling = false
    var isDead = false
    var isFlying = false         // jetpack
    var onTrainTop: Bool = false
    var trainTopY: Float = 0

    private var jumpT: TimeInterval = 0
    private let jumpDuration: TimeInterval = 0.7
    private var rollT: TimeInterval = 0
    private let rollDuration: TimeInterval = 0.6
    private var stumbleT: TimeInterval = 0
    private var laneLerpT: TimeInterval = 1
    private var laneFromX: Float = 0

    init() {
        buildOtter()
    }

    static func material(_ color: UIColor, roughness: CGFloat = 0.8) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.roughness.contents = roughness
        m.lightingModel = .physicallyBased
        return m
    }

    private func buildOtter() {
        let brown = Self.material(UIColor(red: 0.545, green: 0.353, blue: 0.169, alpha: 1)) // #8B5A2B
        let tan = Self.material(UIColor(red: 0.851, green: 0.702, blue: 0.510, alpha: 1))   // #D9B382
        let blue = Self.material(UIColor(red: 0.118, green: 0.388, blue: 1.0, alpha: 1))    // #1E63FF
        let black = Self.material(.black, roughness: 0.3)
        let white = Self.material(.white, roughness: 0.4)

        // body: elongated otter capsule
        let body = SCNCapsule(capRadius: 0.42, height: 1.5)
        body.materials = [brown]
        let bodyN = SCNNode(geometry: body)
        bodyN.position = SCNVector3(0, 1.1, 0)
        bodyN.rotation = SCNVector4(1, 0, 0, Float.pi / 12)
        bodyNode.addChildNode(bodyN)

        // blue hoodie band around the upper body
        let hoodie = SCNBox(width: 0.9, height: 0.45, length: 0.78, chamferRadius: 0.15)
        hoodie.materials = [blue]
        let h = SCNNode(geometry: hoodie)
        h.position = SCNVector3(0, 1.45, 0)
        bodyNode.addChildNode(h)
        // hood bump behind head
        let hood = SCNSphere(radius: 0.18)
        hood.materials = [blue]
        let hn = SCNNode(geometry: hood)
        hn.scale = SCNVector3(1, 0.7, 0.8)
        hn.position = SCNVector3(0, 1.78, -0.28)
        bodyNode.addChildNode(hn)

        // belly
        let belly = SCNSphere(radius: 0.3)
        belly.materials = [tan]
        let bellyN = SCNNode(geometry: belly)
        bellyN.scale = SCNVector3(1, 1.4, 0.55)
        bellyN.position = SCNVector3(0, 1.05, 0.3)
        bodyNode.addChildNode(bellyN)

        // head
        let head = SCNSphere(radius: 0.45)
        head.materials = [brown]
        let headN = SCNNode(geometry: head)
        headN.position = SCNVector3(0, 2.15, 0.08)
        bodyNode.addChildNode(headN)

        // white muzzle patch
        let muzzle = SCNSphere(radius: 0.19)
        muzzle.materials = [white]
        let muzzleN = SCNNode(geometry: muzzle)
        muzzleN.scale = SCNVector3(1.1, 0.8, 1)
        muzzleN.position = SCNVector3(0, 2.05, 0.45)
        bodyNode.addChildNode(muzzleN)

        // nose
        let nose = SCNSphere(radius: 0.07)
        nose.materials = [black]
        let noseN = SCNNode(geometry: nose)
        noseN.position = SCNVector3(0, 2.12, 0.62)
        bodyNode.addChildNode(noseN)

        // eyes
        for side: Float in [-1, 1] {
            let eye = SCNSphere(radius: 0.055)
            eye.materials = [black]
            let e = SCNNode(geometry: eye)
            e.position = SCNVector3(0.17 * side, 2.28, 0.42)
            bodyNode.addChildNode(e)
            let glint = SCNSphere(radius: 0.018)
            glint.materials = [white]
            let g = SCNNode(geometry: glint)
            g.position = SCNVector3(0.18 * side, 2.29, 0.47)
            bodyNode.addChildNode(g)
        }

        // small round ears
        for side: Float in [-1, 1] {
            let ear = SCNSphere(radius: 0.11)
            ear.materials = [brown]
            let e = SCNNode(geometry: ear)
            e.scale = SCNVector3(1, 1, 0.5)
            e.position = SCNVector3(0.3 * side, 2.5, 0.0)
            bodyNode.addChildNode(e)
        }

        // whiskers
        for side: Float in [-1, 1] {
            for i in 0..<2 {
                let w = SCNCylinder(radius: 0.006, height: 0.28)
                w.materials = [white]
                let wn = SCNNode(geometry: w)
                wn.position = SCNVector3(0.32 * side, 2.02 + Float(i) * 0.05, 0.42)
                wn.rotation = SCNVector4(0, 0, 1, Float.pi / 2 + Float(side) * 0.2)
                bodyNode.addChildNode(wn)
            }
        }

        // prominent long flat tail trailing behind
        let tail = SCNBox(width: 0.35, height: 0.12, length: 0.9, chamferRadius: 0.05)
        tail.materials = [brown]
        let tailN = SCNNode(geometry: tail)
        tailN.position = SCNVector3(0, 0.55, -0.85)
        tailN.rotation = SCNVector4(1, 0, 0, -0.5)
        bodyNode.addChildNode(tailN)
        tailNode = tailN

        // legs (animated) + paw feet
        for side: Float in [-1, 1] {
            let legPivot = SCNNode()
            legPivot.position = SCNVector3(0.18 * side, 0.6, 0)
            let leg = SCNCapsule(capRadius: 0.09, height: 0.35)
            leg.materials = [brown]
            let l = SCNNode(geometry: leg)
            l.position = SCNVector3(0, -0.18, 0)
            legPivot.addChildNode(l)
            let paw = SCNSphere(radius: 0.1)
            paw.materials = [tan]
            let p = SCNNode(geometry: paw)
            p.scale = SCNVector3(1, 0.6, 1.4)
            p.position = SCNVector3(0, -0.38, 0.05)
            legPivot.addChildNode(p)
            bodyNode.addChildNode(legPivot)
            if side < 0 { legL = legPivot } else { legR = legPivot }
        }

        // slim arms hanging at the sides (animated swing)
        for side: Float in [-1, 1] {
            let armPivot = SCNNode()
            armPivot.position = SCNVector3(0.48 * side, 1.6, 0.05)
            let arm = SCNCapsule(capRadius: 0.13, height: 0.55)
            arm.materials = [blue]
            let a = SCNNode(geometry: arm)
            a.position = SCNVector3(0, -0.3, 0)
            armPivot.addChildNode(a)
            let paw = SCNSphere(radius: 0.08)
            paw.materials = [tan]
            let p = SCNNode(geometry: paw)
            p.position = SCNVector3(0, -0.62, 0)
            armPivot.addChildNode(p)
            bodyNode.addChildNode(armPivot)
            if side < 0 { armL = armPivot } else { armR = armPivot }
        }

        // blue backpack
        let pack = SCNBox(width: 0.4, height: 0.5, length: 0.18, chamferRadius: 0.06)
        pack.materials = [blue]
        let packN = SCNNode(geometry: pack)
        packN.position = SCNVector3(0, 1.45, -0.48)
        bodyNode.addChildNode(packN)

        node.addChildNode(bodyNode)

        // soft blob shadow under him
        let shadow = SCNCylinder(radius: 0.45, height: 0.01)
        let sm = SCNMaterial()
        sm.diffuse.contents = UIColor.black.withAlphaComponent(0.35)
        sm.lightingModel = .constant
        shadow.materials = [sm]
        let sh = SCNNode(geometry: shadow)
        sh.position = SCNVector3(0, 0.02, 0)
        node.addChildNode(sh)
        shadowNode = sh
    }

    // MARK: - Power-up visuals

    func setJetpackVisual(_ on: Bool) {
        jetpackNode?.removeFromParentNode()
        jetpackNode = nil
        guard on else { return }
        let jp = SCNNode()
        let blue = Self.material(UIColor(red: 0.122, green: 0.435, blue: 0.910, alpha: 1), roughness: 0.3)
        for side: Float in [-1, 1] {
            let tank = SCNCylinder(radius: 0.09, height: 0.45)
            tank.materials = [blue]
            let t = SCNNode(geometry: tank)
            t.position = SCNVector3(0.14 * side, 0, 0)
            jp.addChildNode(t)
        }
        // flickering flame cone
        let flame = SCNCone(topRadius: 0.12, bottomRadius: 0.02, height: 0.5)
        let fm = SCNMaterial()
        fm.diffuse.contents = UIColor.orange
        fm.emission.contents = UIColor.orange
        flame.materials = [fm]
        let f = SCNNode(geometry: flame)
        f.rotation = SCNVector4(1, 0, 0, Float.pi)
        f.position = SCNVector3(0, -0.45, 0)
        f.name = "flame"
        jp.addChildNode(f)
        jp.position = SCNVector3(0, 1.05, -0.5)
        bodyNode.addChildNode(jp)
        jetpackNode = jp
    }

    func setSneakersVisual(_ on: Bool) {
        sneakersNode?.removeFromParentNode()
        sneakersNode = nil
        guard on else { return }
        let sn = SCNNode()
        let orange = Self.material(.systemOrange, roughness: 0.5)
        for side: Float in [-1, 1] {
            let shoe = SCNBox(width: 0.14, height: 0.1, length: 0.28, chamferRadius: 0.04)
            shoe.materials = [orange]
            let s = SCNNode(geometry: shoe)
            s.position = SCNVector3(0.15 * side, 0.1, 0.06)
            sn.addChildNode(s)
        }
        node.addChildNode(sn)
        sneakersNode = sn
    }

    // MARK: - Actions

    func moveLane(dir: Int) {
        guard !isDead else { return }
        lane = max(0, min(2, lane + dir))
        laneFromX = node.position.x
        laneLerpT = 0
    }

    func jump(superSneakers: Bool = false) -> Bool {
        guard !isDead, !isJumping, !isFlying else { return false }
        isJumping = true
        isRolling = false
        bodyNode.scale = SCNVector3(1, 1, 1)
        jumpT = 0
        jumpPeak = superSneakers ? 2.2 * 1.8 : 2.2
        return true
    }
    private var jumpPeak: Float = 2.2

    func roll() -> Bool {
        guard !isDead, !isFlying else { return false }
        if isJumping { isJumping = false; visualY = 0 }
        isRolling = true
        rollT = 0
        return true
    }

    func laneLerpDone() {
        laneLerpT = 1
        node.position.x = laneX
    }

    func stumble() {
        isStumbling = true
        stumbleT = 0
    }

    func die() {
        isDead = true
        let fall = SCNAction.rotateBy(x: 0, y: 0, z: .pi / 2, duration: 0.4)
        let drop = SCNAction.moveBy(x: 0, y: -0.3, z: 0, duration: 0.4)
        node.runAction(.group([fall, drop]))
    }

    func hitbox() -> (minY: Float, maxY: Float, halfW: Float, halfD: Float) {
        let base = node.position.y
        if isRolling {
            return (base, base + 0.7, 0.4, 0.5)
        }
        return (base + 0.25, base + 1.8, 0.4, 0.5)
    }

    func idleUpdate(dt: TimeInterval) {
        runTime += dt
        bodyNode.position.y = abs(sin(Float(runTime) * 3)) * 0.08
        if let tail = tailNode {
            tail.rotation = SCNVector4(1, 0, 0, -0.4 + Float(sin(runTime * 4) * 0.15))
        }
    }

    func update(dt: TimeInterval, speed: Double, flying: Bool, groundY: Float) {
        guard !isDead else { return }
        runTime += dt
        isFlying = flying

        // lane lerp over ~0.12s with slight tilt
        if laneLerpT < 1 {
            laneLerpT = min(1, laneLerpT + dt / 0.12)
            let t = laneLerpT
            let e = Float(t * t * (3 - 2 * t))
            node.position.x = laneFromX + (laneX - laneFromX) * e
            node.rotation = SCNVector4(0, 0, 1, (laneX - node.position.x) * -0.12)
        } else {
            node.position.x = laneX
            node.rotation = SCNVector4(0, 0, 1, 0)
        }

        // flying (jetpack)
        if flying {
            visualY = 6
            isJumping = false
        } else if isJumping {
            let dur = jumpDuration * (12.0 / max(speed, 8)) + 0.35
            jumpT += dt
            let t = Float(min(1, jumpT / dur))
            visualY = jumpPeak * 4 * t * (1 - t)
            if t >= 1 { isJumping = false; visualY = 0 }
        } else {
            visualY = 0
        }

        var y = visualY + groundY
        if onTrainTop { y = trainTopY }

        // stumble wobble
        if isStumbling {
            stumbleT += dt
            if stumbleT > 0.6 { isStumbling = false }
            let w = sin(Float(stumbleT * 30)) * 0.15 * Float(max(0, 0.6 - stumbleT))
            node.rotation = SCNVector4(0, 0, 1, w)
        }

        // roll squash
        if isRolling {
            rollT += dt
            bodyNode.scale = SCNVector3(1, 0.5, 1.1)
            if rollT > rollDuration {
                isRolling = false
                bodyNode.scale = SCNVector3(1, 1, 1)
            }
        } else {
            bodyNode.scale = SCNVector3(1, 1, 1)
        }

        // run bob + limb swing + tail wag
        let runPhase = Float(runTime) * 14
        let bob = flying ? 0 : abs(sin(runPhase)) * 0.12
        bodyNode.position.y = bob
        armL?.rotation = SCNVector4(1, 0, 0, sin(runPhase) * 0.9)
        armR?.rotation = SCNVector4(1, 0, 0, -sin(runPhase) * 0.9)
        legL?.rotation = SCNVector4(1, 0, 0, -sin(runPhase) * 0.8)
        legR?.rotation = SCNVector4(1, 0, 0, sin(runPhase) * 0.8)
        if let tail = tailNode {
            tail.rotation = SCNVector4(1, 0, 0, -0.4 + Float(sin(runTime * 10) * 0.25))
        }
        if flying {
            bodyNode.rotation = SCNVector4(1, 0, 0, -0.5)
            // flame flicker
            if let flame = jetpackNode?.childNode(withName: "flame", recursively: true) {
                let s = Float.random(in: 0.8...1.3)
                flame.scale = SCNVector3(1, s, 1)
            }
        } else {
            bodyNode.rotation = SCNVector4(0, 0, 0, 0)
        }

        // shadow stays on the ground
        shadowNode?.position.y = -y + 0.02
        let shrink = max(0.3, 1 - y / 8)
        shadowNode?.scale = SCNVector3(shrink, 1, shrink)

        node.position.y = y
    }
}
