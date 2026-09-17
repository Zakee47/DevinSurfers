import SceneKit
import UIKit

final class Player {
    let node = SCNNode()      // root at lane position
    let bodyNode = SCNNode()  // visual body (bobs, squashes)
    private var tailNode: SCNNode?
    private var runTime: TimeInterval = 0

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

        // body: capsule
        let body = SCNCapsule(capRadius: 0.32, height: 0.9)
        body.materials = [brown]
        let bodyN = SCNNode(geometry: body)
        bodyN.position = SCNVector3(0, 0.85, 0)
        bodyN.rotation = SCNVector4(1, 0, 0, Float.pi / 10)
        bodyNode.addChildNode(bodyN)

        // belly
        let belly = SCNSphere(radius: 0.24)
        belly.materials = [tan]
        let bellyN = SCNNode(geometry: belly)
        bellyN.scale = SCNVector3(1, 1.2, 0.55)
        bellyN.position = SCNVector3(0, 0.8, 0.22)
        bodyNode.addChildNode(bellyN)

        // head
        let head = SCNSphere(radius: 0.30)
        head.materials = [brown]
        let headN = SCNNode(geometry: head)
        headN.position = SCNVector3(0, 1.45, 0.05)
        bodyNode.addChildNode(headN)

        // muzzle
        let muzzle = SCNSphere(radius: 0.13)
        muzzle.materials = [tan]
        let muzzleN = SCNNode(geometry: muzzle)
        muzzleN.scale = SCNVector3(1.1, 0.8, 1)
        muzzleN.position = SCNVector3(0, 1.38, 0.30)
        bodyNode.addChildNode(muzzleN)

        // nose
        let nose = SCNSphere(radius: 0.055)
        nose.materials = [black]
        let noseN = SCNNode(geometry: nose)
        noseN.position = SCNVector3(0, 1.42, 0.42)
        bodyNode.addChildNode(noseN)

        // eyes
        for side: Float in [-1, 1] {
            let eye = SCNSphere(radius: 0.045)
            eye.materials = [black]
            let e = SCNNode(geometry: eye)
            e.position = SCNVector3(0.12 * side, 1.52, 0.28)
            bodyNode.addChildNode(e)
            let glint = SCNSphere(radius: 0.015)
            glint.materials = [white]
            let g = SCNNode(geometry: glint)
            g.position = SCNVector3(0.13 * side, 1.53, 0.32)
            bodyNode.addChildNode(g)
        }

        // ears
        for side: Float in [-1, 1] {
            let ear = SCNSphere(radius: 0.09)
            ear.materials = [brown]
            let e = SCNNode(geometry: ear)
            e.scale = SCNVector3(1, 1, 0.5)
            e.position = SCNVector3(0.2 * side, 1.68, 0.02)
            bodyNode.addChildNode(e)
        }

        // whiskers
        for side: Float in [-1, 1] {
            for i in 0..<2 {
                let w = SCNCylinder(radius: 0.006, height: 0.28)
                w.materials = [white]
                let wn = SCNNode(geometry: w)
                wn.position = SCNVector3(0.22 * side, 1.36 + Float(i) * 0.05, 0.30)
                wn.rotation = SCNVector4(0, 0, 1, Float.pi / 2 + Float(side) * 0.2)
                bodyNode.addChildNode(wn)
            }
        }

        // tail: flat scaled box trailing back
        let tail = SCNBox(width: 0.18, height: 0.06, length: 0.7, chamferRadius: 0.03)
        tail.materials = [brown]
        let tailN = SCNNode(geometry: tail)
        tailN.position = SCNVector3(0, 0.45, -0.55)
        tailN.rotation = SCNVector4(1, 0, 0, -0.4)
        bodyNode.addChildNode(tailN)
        tailNode = tailN

        // paws (feet)
        for side: Float in [-1, 1] {
            let paw = SCNSphere(radius: 0.09)
            paw.materials = [tan]
            let p = SCNNode(geometry: paw)
            p.scale = SCNVector3(1, 0.6, 1.4)
            p.position = SCNVector3(0.15 * side, 0.38, 0.15)
            bodyNode.addChildNode(p)
        }

        // Devin-blue hoodie band / scarf around neck
        let scarf = SCNTorus(ringRadius: 0.24, pipeRadius: 0.07)
        scarf.materials = [blue]
        let scarfN = SCNNode(geometry: scarf)
        scarfN.position = SCNVector3(0, 1.2, 0.03)
        scarfN.rotation = SCNVector4(1, 0, 0, Float.pi / 2)
        bodyNode.addChildNode(scarfN)

        // blue backpack
        let pack = SCNBox(width: 0.34, height: 0.42, length: 0.16, chamferRadius: 0.05)
        pack.materials = [blue]
        let packN = SCNNode(geometry: pack)
        packN.position = SCNVector3(0, 1.05, -0.33)
        bodyNode.addChildNode(packN)

        node.addChildNode(bodyNode)
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
        jumpT = 0
        jumpPeak = superSneakers ? 2.2 * 1.8 : 2.2
        return true
    }
    private var jumpPeak: Float = 2.2

    func roll() -> Bool {
        guard !isDead, !isFlying else { return false }
        // rolling cancels a jump early
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

    // Hitbox: returns (minY, maxY, halfWidth)
    func hitbox() -> (minY: Float, maxY: Float, halfW: Float, halfD: Float) {
        let base = node.position.y
        if isRolling {
            return (base, base + 0.7, 0.4, 0.5)
        }
        return (base + 0.25, base + 1.75, 0.4, 0.5)
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

        // running on top of a train
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

        // run bob + tail wag
        let bob = flying ? 0 : abs(sin(Float(runTime) * 14)) * 0.12
        bodyNode.position.y = bob
        if let tail = tailNode {
            tail.rotation = SCNVector4(1, 0, 0, -0.4 + Float(sin(runTime * 10) * 0.25))
        }
        if flying {
            bodyNode.rotation = SCNVector4(1, 0, 0, -0.5)
        } else {
            bodyNode.rotation = SCNVector4(0, 0, 0, 0)
        }

        node.position.y = y
    }
}
