import Combine
import QuartzCore
import SceneKit
import UIKit

final class GameScene: NSObject, SCNSceneRendererDelegate {
    let scene = SCNScene()
    let player = Player()
    let track = TrackManager()
    let chaser = Chaser()
    private(set) var state: GameState

    private var cameraNode = SCNNode()
    private let menuStage = SCNNode()
    private var lastTime: TimeInterval = 0
    private var shakeT: TimeInterval = 0
    private var invulnT: TimeInterval = 0
    private var hoverboardT: TimeInterval = 0
    private var hoverboardNode: SCNNode?
    private var speed: Double = 6
    private var runUpT: TimeInterval = 0
    private var runTime: TimeInterval = 0
    private var distMilestone = 0
    private var camX: Float = 0
    private var cancellables = Set<AnyCancellable>()

    init(state: GameState) {
        self.state = state
        super.init()
        buildScene()
        wireCallbacks()
        observePhase()
    }

    private func skyGradient() -> UIImage {
        let size = CGSize(width: 2, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let colors = [
                UIColor(red: 0.310, green: 0.639, blue: 0.910, alpha: 1).cgColor,  // #4FA3E8
                UIColor(red: 0.749, green: 0.890, blue: 1.000, alpha: 1).cgColor,  // #BFE3FF
            ]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 0, y: size.height),
                options: [])
        }
    }

    private func buildScene() {
        let skyTop = UIColor(red: 0.310, green: 0.639, blue: 0.910, alpha: 1)
        let skyHorizon = UIColor(red: 0.749, green: 0.890, blue: 1.0, alpha: 1)
        scene.background.contents = skyGradient()
        scene.fogStartDistance = 60
        scene.fogEndDistance = 95
        scene.fogColor = skyHorizon
        _ = skyTop

        // camera: low & close like SS
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 58
        cameraNode.position = SCNVector3(0, 4.0, 6.5)
        cameraNode.look(at: SCNVector3(0, 1.3, -10))
        scene.rootNode.addChildNode(cameraNode)

        // sunlight: warm white directional
        let dir = SCNLight()
        dir.type = .directional
        dir.intensity = 1100
        dir.color = UIColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 1)
        dir.castsShadow = true
        dir.shadowMapSize = CGSize(width: 1024, height: 1024)
        dir.shadowRadius = 4
        dir.orthographicScale = 20
        let dirN = SCNNode()
        dirN.light = dir
        dirN.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 6, 0)
        scene.rootNode.addChildNode(dirN)

        // bright ambient
        let amb = SCNLight()
        amb.type = .ambient
        amb.intensity = 550
        amb.color = UIColor(red: 0.75, green: 0.8, blue: 0.95, alpha: 1)
        let ambN = SCNNode()
        ambN.light = amb
        scene.rootNode.addChildNode(ambN)

        scene.rootNode.addChildNode(track.root)
        scene.rootNode.addChildNode(player.node)
        scene.rootNode.addChildNode(chaser.node)
        player.node.position = SCNVector3(0, 0, 0)
        buildMenuStage()
    }

    private func buildMenuStage() {
        let platform = SCNNode(geometry: SCNCylinder(radius: 1.45, height: 0.14))
        platform.geometry?.materials = [Player.material(UIColor(red: 0.09, green: 0.17, blue: 0.23, alpha: 1))]
        platform.position.y = -0.09
        menuStage.addChildNode(platform)
        let ring = SCNNode(geometry: SCNTorus(ringRadius: 1.43, pipeRadius: 0.014))
        let glow = Player.material(.systemMint)
        glow.emission.contents = UIColor.systemMint.withAlphaComponent(0.5)
        ring.geometry?.materials = [glow]
        ring.position.y = -0.005
        menuStage.addChildNode(ring)
        scene.rootNode.addChildNode(menuStage)
    }

    private func showMenuScene() {
        player.prepareForMenu()
        track.root.isHidden = true
        chaser.dismiss()
        menuStage.isHidden = false
        deactivateHoverboard()
        scene.background.contents = UIColor(red: 0.035, green: 0.075, blue: 0.13, alpha: 1)
        cameraNode.position = SCNVector3(0, 3.1, 6.4)
        cameraNode.camera?.fieldOfView = 52
        cameraNode.look(at: SCNVector3(0, 1.8, 0))
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
                if kind == .jetpack { self.player.setJetpackVisual(true) }
                if kind == .superSneakers { self.player.setSneakersVisual(true) }
            }
        }
        track.onStumble = { [weak self] in
            guard let self, !self.player.isDead else { return }
            if self.invulnT > 0 { return }
            GameAudio.shared.stumble()
            GameAudio.shared.haptic(.heavy)
            self.shakeT = 0.5
            if self.chaser.active {
                self.die(cause: "CAUGHT BY AI SLOP")
            } else {
                self.chaser.trigger(duration: 6)
                self.state.chaserPresent = true
                self.state.stumbleFlash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.state.stumbleFlash = false
                }
            }
        }
        track.onCrash = { [weak self] _ in
            guard let self, !self.player.isDead else { return }
            if self.invulnT > 0 { return }
            if self.state.hoverboardActive {
                self.deactivateHoverboard()
                self.invulnT = 1.2
                self.shakeT = 0.4
                GameAudio.shared.stumble()
                return
            }
            if self.chaser.active {
                self.die(cause: "CAUGHT!")
            } else {
                self.die(cause: "CRASHED!")
            }
        }
        track.onBarrierJumped = { [weak self] in self?.state.noteBarrierJumped() }
        track.onSignRolled = { [weak self] in self?.state.noteSignRolled() }
        track.onTrainDodged = { [weak self] in self?.state.noteTrainDodged() }
    }

    private func observePhase() {
        state.$phase.sink { [weak self] phase in
            guard let self else { return }
            if phase == .menu {
                self.showMenuScene()
            } else if phase == .playing && self.state.distance == 0 {
                self.resetWorld()
            }
        }.store(in: &cancellables)
        state.$hoverboardRequest.sink { [weak self] req in
            guard let self, req else { return }
            self.state.hoverboardRequest = false
            self.activateHoverboard()
        }.store(in: &cancellables)
    }

    func resetWorld() {
        track.reset()
        player.prepareForRun()
        track.root.isHidden = false
        menuStage.isHidden = true
        scene.background.contents = skyGradient()
        cameraNode.camera?.fieldOfView = 58
        cameraNode.position = SCNVector3(0, 4, 6.5)
        cameraNode.look(at: SCNVector3(0, 1.3, -10))
        chaser.dismiss()
        speed = 6
        runUpT = 0
        runTime = 0
        distMilestone = 0
        hoverboardT = 0
        invulnT = 0
        shakeT = 0
        camX = 0
        deactivateHoverboard()
        // SS-style intro: inspector + dog right behind, drops back + fades over ~3s
        chaser.trigger(duration: 3, intro: true)
        chaser.node.position = SCNVector3(0.6, 0, 2.4)
        state.dyingText = nil
        lastTime = 0
    }

    // MARK: - Input

    func swipeLeft() {
        guard state.phase == .playing else { return }
        player.moveLane(dir: -1)
        GameAudio.shared.swipe()
    }
    func swipeRight() {
        guard state.phase == .playing else { return }
        player.moveLane(dir: 1)
        GameAudio.shared.swipe()
    }
    func swipeUp() {
        guard state.phase == .playing else { return }
        if player.jump(superSneakers: state.activePowerUps[.superSneakers] != nil) {
            state.noteJump()
            GameAudio.shared.jump()
        }
    }
    func swipeDown() {
        guard state.phase == .playing else { return }
        if player.roll() {
            state.noteRoll()
            GameAudio.shared.swipe()
        }
    }
    func doubleTap() { activateHoverboard() }
    func tapPause() {
        if state.phase == .playing { state.phase = .paused } else if state.phase == .paused { state.phase = .playing }
    }

    func activateHoverboard() {
        guard state.phase == .playing, !player.isDead, !state.hoverboardActive, state.hoverboardCharges > 0 else { return }
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
        guard state.phase == .playing, !player.isDead else { return }
        player.die()
        chaser.grabAt(playerX: player.node.position.x)
        GameAudio.shared.crash()
        GameAudio.shared.haptic(.heavy)
        shakeT = 0.8
        state.dyingText = cause
        let runID = state.runID
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self, self.state.runID == runID, self.player.isDead else { return }
            self.state.dyingText = nil
            self.state.endRun(cause: cause == "CRASHED!" ? "CRASHED INTO AI SLOP" : "CAUGHT BY AI SLOP", runID: runID)
        }
    }

    // MARK: - Render loop

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async { [weak self] in
            self?.update(atTime: time)
        }
    }

    private func update(atTime time: TimeInterval) {
        dispatchPrecondition(condition: .onQueue(.main))
        if state.phase == .menu {
            player.idleUpdate(dt: 1.0 / 60)
            return
        }
        guard state.phase == .playing, !player.isDead else {
            lastTime = time
            return
        }
        var dt = lastTime == 0 ? 0 : time - lastTime
        lastTime = time
        dt = min(dt, 0.05)
        runTime += dt

        // run-up: 6 -> 12 over first second, then difficulty ramp to 30 over ~3 min
        runUpT += dt
        let baseSpeed = runUpT < 1 ? 6 + runUpT * 6 : 12
        speed = min(30, baseSpeed + state.distance / 600 * 18)

        let jetpackOn = state.activePowerUps[.jetpack] != nil
        let magnetOn = state.activePowerUps[.magnet] != nil

        track.update(
            dt: dt, speed: speed, player: player,
            magnetOn: magnetOn, jetpackOn: jetpackOn, distance: state.distance)
        guard !player.isDead else { return }

        player.update(dt: dt, speed: speed, flying: jetpackOn, groundY: 0)
        if !jetpackOn && player.jetpackNode != nil { player.setJetpackVisual(false) }
        if state.activePowerUps[.superSneakers] == nil && player.sneakersNode != nil {
            player.setSneakersVisual(false)
        }
        chaser.update(dt: dt, playerX: player.node.position.x, camX: camX)
        if !chaser.active && state.chaserPresent && state.dyingText == nil { state.chaserPresent = false }

        state.tick(dt: dt, speed: speed)
        if Int(state.distance) / 50 > distMilestone {
            distMilestone = Int(state.distance) / 50
            state.noteDistanceMilestone()
        }

        if invulnT > 0 { invulnT -= dt }

        if state.hoverboardActive {
            hoverboardT -= dt
            state.activePowerUps[.hoverboardPickup] = max(0, hoverboardT)
            if hoverboardT <= 0 { deactivateHoverboard() }
        }

        // camera: follows player x fully with slight lag
        camX += (player.node.position.x - camX) * Float(min(1, dt * 10))
        var cx = camX
        if shakeT > 0 {
            shakeT -= dt
            cx += Float.random(in: -0.2...0.2) * Float(shakeT)
            cameraNode.position.y = 4.0 + Float.random(in: -0.2...0.2) * Float(shakeT)
        } else {
            cameraNode.position.y = 4.0 + player.node.position.y * 0.3
        }
        cameraNode.position.x = cx
        let lookY: Float = 1.3 + player.node.position.y * 0.4
        cameraNode.look(at: SCNVector3(cx, lookY, -10))
        if jetpackOn {
            cameraNode.eulerAngles.x -= 0.15  // slight extra down-tilt while flying
        }
    }
}
