import SceneKit
import QuartzCore
import Combine

final class GameScene: NSObject, SCNSceneRendererDelegate {
    let scene = SCNScene()
    let player = Player()
    let track = TrackManager()
    let chaser = Chaser()
    private(set) var state: GameState

    private var cameraNode = SCNNode()
    private var lastTime: TimeInterval = 0
    private var shakeT: TimeInterval = 0
    private var invulnT: TimeInterval = 0
    private var hoverboardT: TimeInterval = 0
    private var hoverboardNode: SCNNode?
    private var speed: Double = 12
    private var distMilestone = 0
    private var cancellables = Set<AnyCancellable>()

    init(state: GameState) {
        self.state = state
        super.init()
        buildScene()
        wireCallbacks()
        observePhase()
    }

    private func buildScene() {
        scene.background.contents = UIColor(red: 0.03, green: 0.04, blue: 0.12, alpha: 1)
        scene.fogStartDistance = 55
        scene.fogEndDistance = 92
        scene.fogColor = UIColor(red: 0.03, green: 0.04, blue: 0.12, alpha: 1)

        // camera
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 60
        cameraNode.position = SCNVector3(0, 4.5, 7)
        cameraNode.look(at: SCNVector3(0, 1.5, -6))
        scene.rootNode.addChildNode(cameraNode)

        // lighting
        let dir = SCNLight()
        dir.type = .directional
        dir.intensity = 900
        dir.castsShadow = true
        dir.shadowMapSize = CGSize(width: 1024, height: 1024)
        dir.shadowRadius = 4
        let dirN = SCNNode()
        dirN.light = dir
        dirN.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 6, 0)
        scene.rootNode.addChildNode(dirN)

        let amb = SCNLight()
        amb.type = .ambient
        amb.intensity = 350
        amb.color = UIColor(red: 0.4, green: 0.45, blue: 0.6, alpha: 1)
        let ambN = SCNNode()
        ambN.light = amb
        scene.rootNode.addChildNode(ambN)

        scene.rootNode.addChildNode(track.root)
        scene.rootNode.addChildNode(player.node)
        scene.rootNode.addChildNode(chaser.node)
        player.node.position = SCNVector3(0, 0, 0)
    }

    private func wireCallbacks() {
        track.onTokenCollected = { [weak self] in
            guard let self else { return }
            self.state.collectToken()
            GameAudio.shared.coin()
        }
        track.onPowerUp = { [weak self] kind in
            guard let self else { return }
            GameAudio.shared.powerUp()
            GameAudio.shared.haptic(.light)
            if kind == .hoverboardPickup {
                self.state.hoverboardCharges += 1
            } else {
                self.state.activePowerUps[kind] = kind.duration
            }
        }
        track.onStumble = { [weak self] in
            guard let self else { return }
            if self.invulnT > 0 { return }
            GameAudio.shared.stumble()
            GameAudio.shared.haptic(.heavy)
            self.shakeT = 0.5
            if self.chaser.active {
                self.die(cause: "CAUGHT BY AI SLOP")
            } else {
                self.chaser.trigger()
                self.state.chaserPresent = true
                self.state.stumbleFlash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.state.stumbleFlash = false
                }
            }
        }
        track.onCrash = { [weak self] _ in
            guard let self else { return }
            if self.invulnT > 0 { return }
            if self.state.hoverboardActive {
                // hoverboard consumes the hit
                self.deactivateHoverboard()
                self.invulnT = 1.2
                self.shakeT = 0.4
                GameAudio.shared.stumble()
                return
            }
            if self.chaser.active {
                self.die(cause: "CAUGHT BY AI SLOP")
            } else {
                self.die(cause: "CRASHED INTO AI SLOP")
            }
        }
        track.onBarrierJumped = { [weak self] in self?.state.noteBarrierJumped() }
        track.onSignRolled = { [weak self] in self?.state.noteSignRolled() }
        track.onTrainDodged = { [weak self] in self?.state.noteTrainDodged() }
    }

    private func observePhase() {
        state.$phase.sink { [weak self] phase in
            guard let self else { return }
            if phase == .playing && self.player.isDead == false && self.state.distance == 0 {
                self.resetWorld()
            }
        }.store(in: &cancellables)
    }

    func resetWorld() {
        track.reset()
        player.node.position = SCNVector3(0, 0, 0)
        player.node.rotation = SCNVector4(0, 0, 0, 0)
        player.isDead = false
        player.isJumping = false
        player.isRolling = false
        player.lane = 1
        player.laneLerpDone()
        player.onTrainTop = false
        chaser.dismiss()
        speed = 12
        distMilestone = 0
        hoverboardT = 0
        invulnT = 0
        deactivateHoverboard()
        lastTime = 0
    }

    // MARK: - Input

    func swipeLeft() { guard state.phase == .playing else { return }; player.moveLane(dir: -1); GameAudio.shared.swipe() }
    func swipeRight() { guard state.phase == .playing else { return }; player.moveLane(dir: 1); GameAudio.shared.swipe() }
    func swipeUp() {
        guard state.phase == .playing else { return }
        if player.jump(superSneakers: state.activePowerUps[.superSneakers] != nil) {
            state.noteJump()
            GameAudio.shared.jump()
        }
    }
    func swipeDown() {
        guard state.phase == .playing else { return }
        if player.roll() { state.noteRoll(); GameAudio.shared.swipe() }
    }
    func doubleTap() { activateHoverboard() }
    func tapPause() {
        if state.phase == .playing { state.phase = .paused }
        else if state.phase == .paused { state.phase = .playing }
    }

    func activateHoverboard() {
        guard state.phase == .playing, !state.hoverboardActive, state.hoverboardCharges > 0 else { return }
        state.hoverboardCharges -= 1
        state.hoverboardActive = true
        state.noteHoverboardUsed()
        state.persist()
        hoverboardT = 30
        GameAudio.shared.powerUp()
        attachHoverboard()
    }

    private func attachHoverboard() {
        let board = SCNNode()
        let geo = SCNBox(width: 0.9, height: 0.08, length: 0.4, chamferRadius: 0.04)
        let m = SCNMaterial()
        m.diffuse.contents = UIColor.systemTeal
        m.emission.contents = UIColor.systemTeal.withAlphaComponent(0.5)
        geo.materials = [m]
        board.geometry = geo
        board.position = SCNVector3(0, 0.05, 0)
        player.node.addChildNode(board)
        hoverboardNode = board
    }

    private func deactivateHoverboard() {
        state.hoverboardActive = false
        hoverboardNode?.removeFromParentNode()
        hoverboardNode = nil
    }

    private func die(cause: String) {
        guard state.phase == .playing else { return }
        player.die()
        GameAudio.shared.crash()
        GameAudio.shared.haptic(.heavy)
        shakeT = 0.8
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.state.endRun(cause: cause)
        }
    }

    // MARK: - Render loop

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard state.phase == .playing else { lastTime = time; return }
        var dt = lastTime == 0 ? 0 : time - lastTime
        lastTime = time
        dt = min(dt, 0.05) // clamp

        // difficulty ramp: 12 -> 30 over ~3 min
        speed = min(30, 12 + state.distance / 600 * 18)

        let jetpackOn = state.activePowerUps[.jetpack] != nil
        let magnetOn = state.activePowerUps[.magnet] != nil

        track.update(dt: dt, speed: speed, player: player,
                     magnetOn: magnetOn, jetpackOn: jetpackOn, distance: state.distance)

        player.update(dt: dt, speed: speed, flying: jetpackOn, groundY: 0)
        chaser.update(dt: dt, playerX: player.node.position.x)
        if !chaser.active && state.chaserPresent { state.chaserPresent = false }

        state.tick(dt: dt, speed: speed)
        if Int(state.distance) / 50 > distMilestone {
            distMilestone = Int(state.distance) / 50
            state.noteDistanceMilestone()
        }

        if invulnT > 0 { invulnT -= dt }

        // hoverboard timer
        if state.hoverboardActive {
            hoverboardT -= dt
            state.activePowerUps[.hoverboardPickup] = max(0, hoverboardT)
            if hoverboardT <= 0 { deactivateHoverboard() }
        }

        // camera follow + shake
        var camX = player.node.position.x * 0.5
        if shakeT > 0 {
            shakeT -= dt
            camX += Float.random(in: -0.2...0.2) * Float(shakeT)
            cameraNode.position.y = 4.5 + Float.random(in: -0.2...0.2) * Float(shakeT)
        } else {
            cameraNode.position.y = 4.5
        }
        cameraNode.position.x = camX
        cameraNode.position.y = 4.5 + player.node.position.y * 0.3
        cameraNode.look(at: SCNVector3(player.node.position.x * 0.5, 1.5 + Float(player.node.position.y) * 0.4, -6))
    }
}
