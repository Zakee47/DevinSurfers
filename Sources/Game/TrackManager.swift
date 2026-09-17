import SceneKit
import UIKit

/// Owns the world: ground segments, side scenery, obstacles, coins, power-ups.
/// Player stays at z=0; the world moves toward +z and is recycled past the camera.
final class TrackManager {
    static let lanePositions: [Float] = [-2.2, 0, 2.2]
    static func laneX(_ lane: Int) -> Float { lanePositions[max(0, min(2, lane))] }

    let root = SCNNode()
    private(set) var obstacles: [Obstacle] = []
    private(set) var collectibles: [Collectible] = []
    private var sceneryNodes: [SCNNode] = []
    private var nextSpawnZ: Float = -20  // world-space z of next chunk (starts negative ahead)
    private var distanceSincePowerUp: Float = 0
    private var lastTunnelZ: Float = 0  // world-z where the last tunnel section spawned
    private var chunksSpawned = 0  // chunks spawned this run
    var onTokenCollected: (() -> Void)?
    var onPowerUp: ((PowerUpKind) -> Void)?
    var onCrash: ((ObstacleKind) -> Void)?
    var onStumble: (() -> Void)?
    var onBarrierJumped: (() -> Void)?
    var onSignRolled: (() -> Void)?
    var onTrainDodged: (() -> Void)?

    private let spawnAhead: Float = -90
    private let recycleZ: Float = 15

    // shared materials
    private lazy var gravel = Obstacle.mat(UIColor(red: 0.725, green: 0.682, blue: 0.604, alpha: 1))  // #B9AE9A
    private lazy var trackBed = Obstacle.mat(UIColor(white: 0.35, alpha: 1))
    private lazy var railMat = Obstacle.mat(UIColor(white: 0.55, alpha: 1), roughness: 0.35, metal: 0.7)
    private lazy var sleeperMat = Obstacle.mat(UIColor(red: 0.42, green: 0.29, blue: 0.18, alpha: 1))
    private lazy var bushMat = Obstacle.mat(UIColor(red: 0.25, green: 0.6, blue: 0.25, alpha: 1))
    private lazy var trunkMat = Obstacle.mat(UIColor(red: 0.4, green: 0.28, blue: 0.15, alpha: 1))
    private lazy var darkInside = Obstacle.mat(UIColor(white: 0.12, alpha: 1))
    private lazy var orangeLight = Obstacle.mat(.orange, roughness: 0.2, emissive: .orange)
    private let graffitiColors: [UIColor] = [.systemPink, .systemTeal, .systemOrange, .systemPurple, .systemGreen]

    init() {}

    // MARK: - Side scenery (all chunked, moves with the world)

    private enum SideStyle { case graffitiWalls, fenceAndBushes, containers }

    private func addSideScenery(from z0: Float, to z1: Float, style: SideStyle, into parent: SCNNode) {
        let mid = (z0 + z1) / 2
        let len = z1 - z0
        for side: Float in [-1, 1] {
            let s = side * 5.6
            switch style {
            case .graffitiWalls:
                let wall = SCNBox(width: 0.4, height: 2.2, length: CGFloat(len), chamferRadius: 0)
                wall.materials = [Obstacle.mat(UIColor(white: 0.6, alpha: 1))]
                let w = SCNNode(geometry: wall)
                w.position = SCNVector3(s, 1.1, mid)
                parent.addChildNode(w)
                // colorful graffiti blocks + white tags
                var gz = z0 + 1.5
                while gz < z1 - 1 {
                    let block = SCNBox(
                        width: 0.1, height: CGFloat(Float.random(in: 0.7...1.4)),
                        length: CGFloat(Float.random(in: 1.5...3)), chamferRadius: 0.05)
                    block.materials = [Obstacle.mat(graffitiColors.randomElement()!)]
                    let b = SCNNode(geometry: block)
                    b.position = SCNVector3(side * 5.35, Float.random(in: 0.8...1.6), gz)
                    parent.addChildNode(b)
                    if Bool.random() {
                        let tag = SCNBox(width: 0.12, height: 0.4, length: 0.8, chamferRadius: 0.02)
                        tag.materials = [Obstacle.mat(.white)]
                        let t = SCNNode(geometry: tag)
                        t.position = SCNVector3(side * 5.3, Float.random(in: 0.9...1.7), gz + 0.6)
                        parent.addChildNode(t)
                    }
                    gz += Float.random(in: 3...5)
                }
            case .fenceAndBushes:
                // chain-link fence posts
                var fz = z0 + 1
                while fz < z1 {
                    let post = SCNBox(width: 0.08, height: 2.0, length: 0.08, chamferRadius: 0)
                    post.materials = [Obstacle.mat(UIColor(white: 0.55, alpha: 1), roughness: 0.4, metal: 0.6)]
                    let p = SCNNode(geometry: post)
                    p.position = SCNVector3(s, 1.0, fz)
                    parent.addChildNode(p)
                    fz += 3
                }
                // fence mesh
                let mesh = SCNBox(width: 0.04, height: 1.9, length: CGFloat(len), chamferRadius: 0)
                mesh.materials = [Obstacle.mat(UIColor(white: 0.7, alpha: 0.55), roughness: 0.5, metal: 0.4)]
                let m = SCNNode(geometry: mesh)
                m.position = SCNVector3(s, 1.0, mid)
                parent.addChildNode(m)
                // bushes behind + occasional at lane edge
                var bz = z0 + 2
                while bz < z1 {
                    let bush = SCNSphere(radius: CGFloat(Float.random(in: 0.5...0.9)))
                    bush.materials = [bushMat]
                    let b = SCNNode(geometry: bush)
                    b.scale = SCNVector3(1, 0.8, 1)
                    b.position = SCNVector3(side * Float.random(in: 6.0...7.5), 0.4, bz)
                    parent.addChildNode(b)
                    bz += Float.random(in: 2.5...5)
                }
            case .containers:
                // stacked shipping containers / warehouse facades
                var cz = z0 + 3
                let contColors: [UIColor] = [.systemOrange, .systemBlue, .systemGreen, .systemRed]
                while cz < z1 - 3 {
                    let levels = Int.random(in: 1...2)
                    for lv in 0..<levels {
                        let c = SCNBox(width: 2.2, height: 2.4, length: 5.5, chamferRadius: 0.08)
                        c.materials = [Obstacle.mat(contColors.randomElement()!)]
                        let cn = SCNNode(geometry: c)
                        cn.position = SCNVector3(side * Float.random(in: 6.2...7.2), 1.2 + Float(lv) * 2.45, cz)
                        parent.addChildNode(cn)
                    }
                    cz += Float.random(in: 6...9)
                }
            }
            // occasional trees behind everything
            if Bool.random() {
                let trunk = SCNCylinder(radius: 0.15, height: 1.6)
                trunk.materials = [trunkMat]
                let t = SCNNode(geometry: trunk)
                t.position = SCNVector3(side * Float.random(in: 7...9), 0.8, mid)
                parent.addChildNode(t)
                let top = SCNSphere(radius: 1.1)
                top.materials = [bushMat]
                let tn = SCNNode(geometry: top)
                tn.scale = SCNVector3(1, 1.3, 1)
                tn.position = SCNVector3(t.position.x, 2.4, mid)
                parent.addChildNode(tn)
            }
        }
    }

    // MARK: - Ground + track

    private func spawnGroundChunk(from z0: Float, to z1: Float, into parent: SCNNode) {
        let len = z1 - z0
        let mid = (z0 + z1) / 2
        // wide gravel field
        let ground = SCNBox(width: 30, height: 0.5, length: CGFloat(len), chamferRadius: 0)
        ground.materials = [gravel]
        let g = SCNNode(geometry: ground)
        g.position = SCNVector3(0, -0.25, mid)
        parent.addChildNode(g)
        // per-lane darker track bed + rails + sleepers
        for lane in 0..<3 {
            let x = Self.laneX(lane)
            let bed = SCNBox(width: 2.0, height: 0.08, length: CGFloat(len), chamferRadius: 0)
            bed.materials = [trackBed]
            let bd = SCNNode(geometry: bed)
            bd.position = SCNVector3(x, 0.01, mid)
            parent.addChildNode(bd)
            for side: Float in [-1, 1] {
                let rail = SCNBox(width: 0.08, height: 0.08, length: CGFloat(len), chamferRadius: 0)
                rail.materials = [railMat]
                let r = SCNNode(geometry: rail)
                r.position = SCNVector3(x + 0.5 * side, 0.09, mid)
                parent.addChildNode(r)
            }
            var s = z0 + 0.5
            while s < z1 {
                let sleeper = SCNBox(width: 1.6, height: 0.07, length: 0.3, chamferRadius: 0)
                sleeper.materials = [sleeperMat]
                let sl = SCNNode(geometry: sleeper)
                sl.position = SCNVector3(x, 0.05, s)
                parent.addChildNode(sl)
                s += 1.4
            }
        }
    }

    // MARK: - Patterns

    private enum Pattern {
        case coinLine, coinArc, barrierRow, lowAndHigh, trainPair, trainCenter, flatbedRun, movingTrain, signGates,
            empty
    }

    private func pickPattern(distance: Double) -> Pattern {
        let d = distance
        var weights: [(Pattern, Int)] = [
            (.coinLine, 30), (.empty, 12), (.barrierRow, 20), (.lowAndHigh, 15), (.signGates, 12),
        ]
        if d > 120 { weights += [(.coinArc, 15), (.trainPair, 12), (.trainCenter, 12), (.flatbedRun, 10)] }
        if d > 400 { weights += [(.movingTrain, 8)] }
        let total = weights.reduce(0) { $0 + $1.1 }
        var r = Int.random(in: 0..<total)
        for (p, w) in weights {
            r -= w
            if r < 0 { return p }
        }
        return .coinLine
    }

    private func addToken(x: Float, y: Float = 0.6, z: Float, into parent: SCNNode) {
        let t = Collectible(kind: .token)
        t.node.position = SCNVector3(x, y, z)
        parent.addChildNode(t.node)
        collectibles.append(t)
    }

    private func addObstacle(_ kind: ObstacleKind, lane: Int, z: Float, into parent: SCNNode, length: Float? = nil)
        -> Obstacle
    {
        let o = Obstacle(kind: kind, length: length)
        o.lane = lane
        o.node.position = SCNVector3(Self.laneX(lane), 0, z)
        parent.addChildNode(o.node)
        obstacles.append(o)
        // SS: every low barrier gets a coin arc over it
        if kind == .lowBarrier || kind == .poleBarrier {
            for i in 0..<7 {
                let t = Float(i) / 6
                let y = 0.6 + 2.4 * 4 * t * (1 - t) * 0.55
                addToken(x: Self.laneX(lane), y: y, z: z + 3.2 - Float(i) * 1.07, into: parent)
            }
        }
        return o
    }

    /// Spawn one gameplay chunk at world-z `z` (negative = ahead).
    private func spawnChunk(at z: Float, distance: Double) -> Float {
        let chunk = SCNNode()
        root.addChildNode(chunk)
        sceneryNodes.append(chunk)
        // first 3 chunks of a run are always coin lines so coins flow immediately
        let pattern: Pattern = chunksSpawned < 3 ? .coinLine : pickPattern(distance: distance)
        chunksSpawned += 1
        var chunkLen: Float = 18
        var coinsAdded = 0

        switch pattern {
        case .coinLine:
            let lane = Int.random(in: 0..<3)
            for i in 0..<Int.random(in: 8...12) {
                addToken(x: Self.laneX(lane), z: z - Float(i) * 2, into: chunk)
                coinsAdded += 1
            }
            chunkLen = 28
        case .coinArc:
            let lane = Int.random(in: 0..<3)
            for i in 0..<7 {
                let t = Float(i) / 6
                let y = 0.6 + 2.4 * 4 * t * (1 - t) * 0.55
                addToken(x: Self.laneX(lane), y: y, z: z - Float(i) * 1.6 - 4, into: chunk)
            }
            _ = addObstacle([.lowBarrier, .poleBarrier].randomElement()!, lane: lane, z: z - 8.8, into: chunk)
            chunkLen = 24
        case .barrierRow:
            let free = Int.random(in: 0..<3)
            for lane in 0..<3 where lane != free {
                _ = addObstacle(
                    [.lowBarrier, .poleBarrier, .fullBarrier, .signpost].randomElement()!, lane: lane, z: z - 8,
                    into: chunk)
            }
            for i in 0..<4 { addToken(x: Self.laneX(free), z: z - Float(i) * 2 - 4, into: chunk) }
            chunkLen = 22
        case .lowAndHigh:
            let lanes = [0, 1, 2].shuffled()
            _ = addObstacle([.lowBarrier, .poleBarrier].randomElement()!, lane: lanes[0], z: z - 8, into: chunk)
            _ = addObstacle(.highBarrier, lane: lanes[1], z: z - 8, into: chunk)
            chunkLen = 22
        case .trainPair:
            let free = Int.random(in: 0..<3)
            for lane in 0..<3 where lane != free {
                let tl = Float.random(in: 16...24)
                _ = addObstacle(.train, lane: lane, z: z - tl / 2 - 4, into: chunk, length: tl)
                // coins on top of the train
                for i in 0..<5 { addToken(x: Self.laneX(lane), y: 3.6, z: z - 6 - Float(i) * 3, into: chunk) }
            }
            for i in 0..<6 { addToken(x: Self.laneX(free), z: z - Float(i) * 3 - 4, into: chunk) }
            chunkLen = 46
        case .trainCenter:
            _ = addObstacle(.train, lane: 1, z: z - 14, into: chunk, length: 20)
            for i in 0..<5 {
                addToken(x: Self.laneX(0), z: z - Float(i) * 3 - 4, into: chunk)
                addToken(x: Self.laneX(2), z: z - Float(i) * 3 - 5.5, into: chunk)
            }
            chunkLen = 42
        case .flatbedRun:
            // flatbed + ramp in one lane, coin row on top, barrier beside
            let lane = Int.random(in: 0..<3)
            _ = addObstacle(.flatbed, lane: lane, z: z - 12, into: chunk, length: 16)
            for i in 0..<5 { addToken(x: Self.laneX(lane), y: 2.0, z: z - 8 - Float(i) * 2.5, into: chunk) }
            let other = (lane + Int.random(in: 1...2)) % 3
            _ = addObstacle([.lowBarrier, .highBarrier].randomElement()!, lane: other, z: z - 10, into: chunk)
            chunkLen = 36
        case .movingTrain:
            let lane = Int.random(in: 0..<3)
            _ = addObstacle(.movingTrain, lane: lane, z: z - 20, into: chunk, length: 20)
            let free = Int.random(in: 0..<3)
            for i in 0..<4 { addToken(x: Self.laneX(free), z: z - Float(i) * 3 - 2, into: chunk) }
            chunkLen = 44
        case .signGates:
            for lane in 0..<3 {
                if lane == 2 || Bool.random() {
                    _ = addObstacle(.highBarrier, lane: lane, z: z - 8, into: chunk)
                } else {
                    _ = addObstacle(.signpost, lane: lane, z: z - 8, into: chunk)
                }
            }
            chunkLen = 22
        case .empty:
            chunkLen = 14
        }

        // SS: nearly every non-train chunk carries at least one coin lane
        let trainPatterns: [Pattern] = [.trainPair, .trainCenter, .movingTrain]
        if coinsAdded == 0, !trainPatterns.contains(pattern) {
            let lane = Int.random(in: 0..<3)
            for i in 0..<6 { addToken(x: Self.laneX(lane), z: z - Float(i) * 2 - 4, into: chunk) }
        }

        // occasional power-up
        distanceSincePowerUp += chunkLen
        if distanceSincePowerUp > 120, Bool.random() {
            distanceSincePowerUp = 0
            let kinds: [PowerUpKind] = [.magnet, .jetpack, .superSneakers, .multiplier2x, .hoverboardPickup]
            let p = Collectible(kind: .powerUp(kinds.randomElement()!))
            p.node.position = SCNVector3(Self.laneX(Int.random(in: 0..<3)), 1.0, z - 6)
            chunk.addChildNode(p.node)
            collectibles.append(p)
        }
        // jetpack coins in the air occasionally
        if Bool.random() && pattern != .empty {
            let lane = Int.random(in: 0..<3)
            for i in 0..<6 { addToken(x: Self.laneX(lane), y: 6, z: z - Float(i) * 3 - 30, into: chunk) }
        }

        // tunnel section occasionally once warmed up, spaced ~200 units apart
        var useTunnel = false
        if distance > 350, z < lastTunnelZ - 200 {
            useTunnel = true
            lastTunnelZ = z
        }

        spawnGroundChunk(from: z - chunkLen - 4, to: z + 2, into: chunk)
        if useTunnel {
            buildTunnel(from: z - 40, to: z, into: chunk)
        } else {
            let styles: [SideStyle] = [.graffitiWalls, .fenceAndBushes, .containers]
            addSideScenery(from: z - chunkLen - 4, to: z + 2, style: styles.randomElement()!, into: chunk)
        }
        return chunkLen
    }

    private func buildTunnel(from z0: Float, to z1: Float, into parent: SCNNode) {
        let len = z1 - z0
        let mid = (z0 + z1) / 2
        // interior: dark walls + ceiling + orange lights
        for side: Float in [-1, 1] {
            let wall = SCNBox(width: 0.5, height: 5, length: CGFloat(len), chamferRadius: 0)
            wall.materials = [darkInside]
            let w = SCNNode(geometry: wall)
            w.position = SCNVector3(4.6 * side, 2.5, mid)
            parent.addChildNode(w)
        }
        let ceil = SCNBox(width: 10, height: 0.5, length: CGFloat(len), chamferRadius: 0)
        ceil.materials = [darkInside]
        let c = SCNNode(geometry: ceil)
        c.position = SCNVector3(0, 4.8, mid)
        parent.addChildNode(c)
        var lz = z0 + 3
        while lz < z1 {
            let lamp = SCNBox(width: 1.2, height: 0.15, length: 0.6, chamferRadius: 0.05)
            lamp.materials = [orangeLight]
            let l = SCNNode(geometry: lamp)
            l.position = SCNVector3(0, 4.5, lz)
            parent.addChildNode(l)
            lz += 6
        }
        // arch entrances at both ends
        for z in [z0, z1] {
            let arch = SCNBox(width: 10.5, height: 2.0, length: 1.2, chamferRadius: 0.1)
            arch.materials = [Obstacle.mat(UIColor(white: 0.3, alpha: 1))]
            let a = SCNNode(geometry: arch)
            a.position = SCNVector3(0, 4.2, z)
            parent.addChildNode(a)
            for side: Float in [-1, 1] {
                let pillar = SCNBox(width: 1.2, height: 4.5, length: 1.2, chamferRadius: 0.05)
                pillar.materials = [Obstacle.mat(UIColor(white: 0.3, alpha: 1))]
                let p = SCNNode(geometry: pillar)
                p.position = SCNVector3(4.6 * side, 2.2, z)
                parent.addChildNode(p)
            }
        }
    }

    // MARK: - Per-frame update

    func update(
        dt: TimeInterval, speed: Double, player: Player,
        magnetOn: Bool, jetpackOn: Bool, distance: Double
    ) {
        let dz = Float(speed * dt)

        for chunk in sceneryNodes {
            chunk.position.z += dz
        }
        var i = 0
        while i < sceneryNodes.count {
            let c = sceneryNodes[i]
            var minZ: Float = 0
            for child in c.childNodes { minZ = min(minZ, child.position.z) }
            if c.position.z + minZ > recycleZ {
                c.removeFromParentNode()
                sceneryNodes.remove(at: i)
            } else {
                i += 1
            }
        }
        obstacles.removeAll { $0.node.parent == nil }
        collectibles.removeAll { $0.node.parent == nil }

        while nextSpawnZ > spawnAhead {
            nextSpawnZ -= spawnChunk(at: nextSpawnZ, distance: distance)
        }
        nextSpawnZ += dz

        // moving trains advance extra
        for o in obstacles where o.kind == .movingTrain {
            o.node.position.z += Float(speed * 0.6 * dt)
        }

        for c in collectibles { c.update(dt: dt) }

        handleCollisions(player: player, magnetOn: magnetOn, jetpackOn: jetpackOn)
    }

    func reset() {
        for n in sceneryNodes { n.removeFromParentNode() }
        sceneryNodes.removeAll()
        obstacles.removeAll()
        collectibles.removeAll()
        nextSpawnZ = -20
        chunksSpawned = 0
        lastTunnelZ = 0
        distanceSincePowerUp = 0
        let approach = SCNNode()
        spawnGroundChunk(from: nextSpawnZ, to: recycleZ, into: approach)
        root.addChildNode(approach)
        sceneryNodes.append(approach)
    }

    // MARK: - Collision

    private func handleCollisions(player: Player, magnetOn: Bool, jetpackOn: Bool) {
        let hb = player.hitbox()
        let px = player.node.position.x

        // collectibles
        for c in collectibles where !c.collected {
            let wp = c.node.worldPosition
            let dx = abs(wp.x - px)
            let dz = abs(wp.z - 0)
            switch c.kind {
            case .token:
                if magnetOn, dx < 4, abs(wp.z) < 8 {
                    let dir = SCNVector3(px - wp.x, 0, -wp.z)
                    let len = max(0.01, sqrt(dir.x * dir.x + dir.z * dir.z))
                    let pull = Float(14) * Float(1.0 / 60) * min(1.5, 6 / len)
                    let local = c.node.position
                    c.node.position = SCNVector3(
                        local.x + dir.x / len * pull,
                        local.y,
                        local.z + dir.z / len * pull
                    )
                }
                let dy = abs(wp.y - player.node.position.y - 0.8)
                if dx < 0.7 && dz < 0.8 && dy < 1.2 {
                    c.collected = true
                    c.node.removeFromParentNode()
                    onTokenCollected?()
                }
            case .powerUp(let p):
                if dx < 0.9 && dz < 0.9 && abs(wp.y - player.node.position.y - 0.8) < 1.4 {
                    c.collected = true
                    c.node.removeFromParentNode()
                    onPowerUp?(p)
                }
            }
        }
        collectibles.removeAll { $0.collected }

        // obstacles
        var landedOnTrain = false
        for o in obstacles {
            let wp = o.node.worldPosition
            let oz0 = wp.z - o.length / 2
            let oz1 = wp.z + o.length / 2
            let overlapZ = oz0 < 0.5 && oz1 > -0.5
            let dx = abs(wp.x - px)
            let overlapX = dx < o.halfW + hb.halfW

            // standing/walking on a train roof or flatbed
            if o.kind == .train || o.kind == .flatbed, overlapX {
                let insideZ = oz0 < -0.4 && oz1 > 0.4
                if insideZ {
                    let feetY = player.node.position.y
                    if o.kind == .flatbed {
                        // run up the ramp / stay on deck
                        landedOnTrain = true
                        player.onTrainTop = true
                        let rampStart = wp.z - o.length / 2 + o.rampZone
                        if 0 > rampStart {
                            // still on the ramp portion
                            let t = max(0, min(1, (0 - (wp.z - o.length / 2)) / max(0.01, o.rampZone)))
                            player.trainTopY = o.trainTopHeight * t
                        } else {
                            player.trainTopY = o.trainTopHeight
                        }
                        continue
                    } else if feetY >= o.trainTopHeight - 0.5,
                        player.isJumping || player.visualY > 0 || player.onTrainTop
                    {
                        landedOnTrain = true
                        player.onTrainTop = true
                        player.trainTopY = o.trainTopHeight
                        continue
                    }
                }
            }

            guard overlapZ, overlapX else {
                if !o.scored, o.kind == .train || o.kind == .movingTrain, wp.z - o.length / 2 > 0.5 {
                    o.scored = true
                    onTrainDodged?()
                }
                if !o.scored, o.kind == .lowBarrier || o.kind == .poleBarrier, wp.z > 0.5 {
                    o.scored = true
                    if player.isJumping { onBarrierJumped?() }
                }
                if !o.scored, o.kind == .highBarrier, wp.z > 0.5 {
                    o.scored = true
                    if player.isRolling { onSignRolled?() }
                }
                continue
            }

            if jetpackOn { continue }

            let yOverlap = hb.maxY > o.minY + o.node.worldPosition.y && hb.minY < o.maxY + o.node.worldPosition.y
            guard yOverlap else { continue }

            switch o.kind {
            case .lowBarrier, .poleBarrier:
                if player.isJumping { continue }
                hit(o, player: player, dx: dx)
            case .highBarrier:
                if player.isRolling { continue }
                hit(o, player: player, dx: dx)
            case .train:
                if player.onTrainTop { continue }
                hit(o, player: player, dx: dx)
            case .flatbed:
                continue  // walkable
            case .movingTrain, .fullBarrier, .signpost:
                hit(o, player: player, dx: dx)
            }
        }
        if !landedOnTrain { player.onTrainTop = false }
    }

    private func hit(_ o: Obstacle, player: Player, dx: Float) {
        let edge = dx > o.halfW - 0.15
        if edge {
            o.node.position.z += Float(2)  // push past so we don't retrigger
            player.stumble()
            onStumble?()
        } else {
            onCrash?(o.kind)
        }
    }
}
