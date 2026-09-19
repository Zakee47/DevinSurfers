import SceneKit
import UIKit

final class Player {
    let node = SCNNode()  // root at lane position
    let bodyNode = SCNNode()  // visual body (bobs, squashes)
    private let facingNode = SCNNode()
    private let laptopNode = SCNNode()
    private let carriedLaptopNode = SCNNode()
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
    var lane: Int = 1  // 0,1,2
    var laneX: Float { TrackManager.laneX(lane) }
    var visualY: Float = 0  // jump height above ground
    var isJumping = false
    var isRolling = false
    var isStumbling = false
    var isDead = false
    var isFlying = false  // jetpack
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
        let brown = Self.material(UIColor(red: 0.96, green: 0.52, blue: 0.14, alpha: 1))
        let tan = Self.material(UIColor(red: 1, green: 0.68, blue: 0.30, alpha: 1))
        let black = Self.material(.black, roughness: 0.3)
        let white = Self.material(.white, roughness: 0.4)

        // body: elongated otter capsule
        let body = SCNCapsule(capRadius: 0.46, height: 1.4)
        body.materials = [brown]
        let bodyN = SCNNode(geometry: body)
        bodyN.position = SCNVector3(0, 1.1, 0)
        bodyN.scale = SCNVector3(1, 1, 0.85)
        bodyNode.addChildNode(bodyN)

        // belly
        let belly = SCNSphere(radius: 0.3)
        belly.materials = [tan]
        let bellyN = SCNNode(geometry: belly)
        bellyN.scale = SCNVector3(1.1, 1.45, 0.55)
        bellyN.position = SCNVector3(0, 1.05, 0.3)
        bodyNode.addChildNode(bellyN)

        // head
        let head = SCNSphere(radius: 0.55)
        head.materials = [tan]
        let headN = SCNNode(geometry: head)
        headN.position = SCNVector3(0, 2.08, 0.08)
        headN.scale = SCNVector3(1, 0.95, 0.85)
        bodyNode.addChildNode(headN)

        for side: Float in [-1, 1] {
            let muzzle = SCNSphere(radius: 0.23)
            muzzle.materials = [white]
            let muzzleN = SCNNode(geometry: muzzle)
            muzzleN.scale = SCNVector3(1, 0.72, 0.65)
            muzzleN.position = SCNVector3(0.15 * side, 1.89, 0.48)
            bodyNode.addChildNode(muzzleN)
        }

        // nose
        let nose = SCNSphere(radius: 0.11)
        nose.materials = [black]
        let noseN = SCNNode(geometry: nose)
        noseN.position = SCNVector3(0, 2.01, 0.64)
        noseN.scale = SCNVector3(1.2, 0.7, 0.65)
        bodyNode.addChildNode(noseN)
        let noseGlint = SCNNode(geometry: SCNSphere(radius: 0.025))
        noseGlint.geometry?.materials = [white]
        noseGlint.position = SCNVector3(-0.02, 2.035, 0.705)
        noseGlint.scale = SCNVector3(1.5, 0.65, 0.5)
        bodyNode.addChildNode(noseGlint)

        // eyes
        for side: Float in [-1, 1] {
            let eye = SCNSphere(radius: 0.10)
            eye.materials = [black]
            let e = SCNNode(geometry: eye)
            e.position = SCNVector3(0.26 * side, 2.23, 0.47)
            e.scale = SCNVector3(0.85, 1.25, 0.6)
            bodyNode.addChildNode(e)
            let glint = SCNSphere(radius: 0.028)
            glint.materials = [white]
            let g = SCNNode(geometry: glint)
            g.position = SCNVector3(0.26 * side - 0.018, 2.27, 0.53)
            bodyNode.addChildNode(g)
        }

        // small round ears
        for side: Float in [-1, 1] {
            let ear = SCNSphere(radius: 0.15)
            ear.materials = [brown]
            let e = SCNNode(geometry: ear)
            e.scale = SCNVector3(1, 1, 0.5)
            e.position = SCNVector3(0.48 * side, 2.37, 0.04)
            bodyNode.addChildNode(e)
            let innerEar = SCNNode(geometry: SCNSphere(radius: 0.08))
            innerEar.geometry?.materials = [Self.material(UIColor(red: 0.55, green: 0.28, blue: 0.10, alpha: 1))]
            innerEar.scale = SCNVector3(1, 1, 0.35)
            innerEar.position = SCNVector3(0.48 * side, 2.37, 0.12)
            bodyNode.addChildNode(innerEar)
        }

        // whiskers
        for side: Float in [-1, 1] {
            for i in 0..<3 {
                let w = SCNCapsule(capRadius: 0.014, height: 0.28)
                w.materials = [black]
                let wn = SCNNode(geometry: w)
                wn.position = SCNVector3(0.38 * side, 1.87 + Float(i) * 0.08, 0.54)
                wn.rotation = SCNVector4(0, 0, 1, Float.pi / 2 + side * Float(i - 1) * 0.35)
                bodyNode.addChildNode(wn)
            }
        }

        let tail = SCNCone(topRadius: 0.035, bottomRadius: 0.28, height: 1.15)
        tail.materials = [brown]
        let tailN = SCNNode(geometry: tail)
        tailN.position = SCNVector3(0, 0.28, -0.85)
        tailN.eulerAngles.x = -.pi / 2
        tailN.scale = SCNVector3(1, 1, 0.5)
        bodyNode.addChildNode(tailN)
        tailNode = tailN

        // legs (animated) + paw feet
        for side: Float in [-1, 1] {
            let legPivot = SCNNode()
            legPivot.position = SCNVector3(0.18 * side, 0.6, 0)
            let leg = SCNCapsule(capRadius: 0.13, height: 0.35)
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
            arm.materials = [brown]
            let a = SCNNode(geometry: arm)
            a.position = SCNVector3(0, -0.3, 0)
            armPivot.addChildNode(a)
            let paw = SCNSphere(radius: 0.13)
            paw.materials = [tan]
            let p = SCNNode(geometry: paw)
            p.position = SCNVector3(0, -0.55, 0)
            armPivot.addChildNode(p)
            bodyNode.addChildNode(armPivot)
            if side < 0 { armL = armPivot } else { armR = armPivot }
        }

        buildLaptop(into: laptopNode, open: true)
        laptopNode.position = SCNVector3(0, 1.02, 0.64)
        bodyNode.addChildNode(laptopNode)
        buildLaptop(into: carriedLaptopNode, open: false)
        carriedLaptopNode.position = SCNVector3(0, 1.05, -0.47)
        carriedLaptopNode.eulerAngles.y = .pi
        bodyNode.addChildNode(carriedLaptopNode)

        facingNode.name = "facing"
        facingNode.addChildNode(bodyNode)
        node.addChildNode(facingNode)
        prepareForRun()

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

    private func buildLaptop(into parent: SCNNode, open: Bool) {
        let dark = Self.material(UIColor(white: 0.06, alpha: 1))
        let silver = Self.material(UIColor(white: 0.78, alpha: 1), roughness: 0.4)
        let lid = SCNNode(geometry: SCNBox(width: 0.84, height: 0.62, length: 0.06, chamferRadius: 0.045))
        lid.geometry?.materials = [dark]
        lid.position.y = 0.29
        lid.eulerAngles.x = open ? -0.18 : 0
        parent.addChildNode(lid)
        let inset = SCNNode(geometry: SCNBox(width: 0.76, height: 0.54, length: 0.02, chamferRadius: 0.025))
        inset.geometry?.materials = [silver]
        inset.position.z = 0.036
        lid.addChildNode(inset)
        if let logoImage = UIImage(named: "CognitionLogo") {
            let logo = SCNPlane(width: 0.44, height: 0.44)
            let ink = SCNMaterial()
            ink.diffuse.contents = logoImage
            ink.diffuse.mipFilter = .linear
            ink.lightingModel = .constant
            ink.transparencyMode = .aOne
            ink.writesToDepthBuffer = false
            logo.materials = [ink]
            let mark = SCNNode(geometry: logo)
            mark.position.z = 0.048
            mark.castsShadow = false
            lid.addChildNode(mark)
        }
        if open {
            let keyboard = SCNNode(geometry: SCNBox(width: 0.84, height: 0.06, length: 0.43, chamferRadius: 0.025))
            keyboard.geometry?.materials = [silver]
            keyboard.position = SCNVector3(0, -0.015, -0.17)
            parent.addChildNode(keyboard)
        }
    }

    func prepareForRun() {
        node.removeAllActions()
        node.position = SCNVector3Zero
        node.eulerAngles = SCNVector3Zero
        facingNode.eulerAngles = SCNVector3(0, Float.pi, 0)
        bodyNode.position = SCNVector3Zero
        bodyNode.eulerAngles = SCNVector3Zero
        bodyNode.scale = SCNVector3(1, 1, 1)
        for limb in [armL, armR, legL, legR] {
            limb?.eulerAngles = SCNVector3Zero
        }
        laptopNode.isHidden = true
        carriedLaptopNode.isHidden = false
        lane = 1
        laneLerpDone()
        visualY = 0
        isJumping = false
        isRolling = false
        isStumbling = false
        isDead = false
        isFlying = false
        onTrainTop = false
        trainTopY = 0
        runTime = 0
        setJetpackVisual(false)
        setSneakersVisual(false)
        shadowNode?.position.y = 0.02
        shadowNode?.scale = SCNVector3(1, 1, 1)
    }

    func prepareForMenu() {
        prepareForRun()
        facingNode.eulerAngles.y = -0.25
        laptopNode.isHidden = false
        carriedLaptopNode.isHidden = true
        armL?.eulerAngles.x = -1.1
        armR?.eulerAngles.x = -1.1
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
        facingNode.addChildNode(sn)
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
        if isJumping {
            isJumping = false
            visualY = 0
        }
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
            tail.eulerAngles.y = Float(sin(runTime * 4) * 0.12)
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
            if t >= 1 {
                isJumping = false
                visualY = 0
            }
        } else {
            visualY = 0
        }

        var y = visualY + groundY
        if onTrainTop && !flying { y = trainTopY + visualY }

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
            tail.eulerAngles.y = Float(sin(runTime * 10) * 0.18)
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
