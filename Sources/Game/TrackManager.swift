import SceneKit
import UIKit

/// Owns the world: ground segments, tunnel walls, obstacles, coins, power-ups.
/// Player stays at z=0; the world moves toward +z and is recycled past the camera.
final class TrackManager {
    static let lanePositions: [Float] = [-2.2, 0, 2.2]
    static func laneX(_ lane: Int) -> Float { lanePositions[max(0, min(2, lane))] }

    let root = SCNNode()
    private(set) var obstacles: [Obstacle] = []
    private(set) var collectibles: [Collectible] = []
    private var sceneryNodes: [SCNNode] = []
    private var nextSpawnZ: Float = -20   // world-space z of next chunk (starts negative ahead)
    private var distanceSincePowerUp: Float = 0
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
    private lazy var concrete = Obstacle.mat(UIColor(white: 0.22, alpha: 1))
    private lazy var railMat = Obstacle.mat(UIColor(white: 0.6, alpha: 1), roughness: 0.3)
    private lazy var sleeperMat = Obstacle.mat(UIColor(red: 0.3, green: 0.22, blue: 0.15, alpha: 1))
    private lazy var wallMat = Obstacle.mat(UIColor(white: 0.28, alpha: 1))
    private lazy var lightMat = Obstacle.mat(.white, roughness: 0.2, emissive: UIColor(white: 0.9, alpha: 1))

    init() {
        buildTunnelShell()
    }

    // MARK: - Static tunnel shell (walls both sides, ceiling lights in moving chunks)

    private func buildTunnelShell() {
        // side walls: long static slabs
        for side: Float in [-1, 1] {
            let wall = SCNBox(width: 0.5, height: 6, length: 220, chamferRadius: 0)
            wall.materials = [wallMat]
            let w = SCNNode(geometry: wall)
            w.position = SCNVector3(5.2 * side, 3, -80)
            root.addChildNode(w)
            // graffiti panels along wall
            let colors: [UIColor] = [.systemPink, .systemTeal, .systemPurple, .systemOrange, .systemGreen]
            for i in 0..<14 {
                let panel = SCNBox(width: 0.1, height: 1.2, length: 2.4, chamferRadius: 0.05)
                panel.materials = [Obstacle.mat(colors.randomElement()!)]
                let p = SCNNode(geometry: panel)
                p.position = SCNVector3(4.9 * side, Float.random(in: 1.2...3.5), -150 + Float(i) * 12)
                root.addChildNode(p)
            }
        }
        // occasional station pillars
        for i in 0..<6 {
            for side: Float in [-1, 1] {
                let pillar = SCNBox(width: 0.7, height: 6, length: 0.7, chamferRadius: 0.05)
                pillar.materials = [wallMat]
                let p = SCNNode(geometry: pillar)
                p.position = SCNVector3(4.4 * side, 3, -20 - Float(i) * 28)
                root.addChildNode(p)
            }
        }
    }

    // MARK: - Chunk spawning

    private func spawnGroundChunk(from z0: Float, to z1: Float, into parent: SCNNode) {
        let len = z1 - z0
        let mid = (z0 + z1) / 2
        let ground = SCNBox(width: 11, height: 0.5, length: CGFloat(len), chamferRadius: 0)
        ground.materials = [concrete]
        let g = SCNNode(geometry: ground)
        g.position = SCNVector3(0, -0.25, mid)
        parent.addChildNode(g)
        // rails + sleepers per lane
        for lane in 0..<3 {
            let x = Self.laneX(lane)
            for side: Float in [-1, 1] {
                let rail = SCNBox(width: 0.08, height: 0.08, length: CGFloat(len), chamferRadius: 0)
                rail.materials = [railMat]
                let r = SCNNode(geometry: rail)
                r.position = SCNVector3(x + 0.5 * side, 0.06, mid)
                parent.addChildNode(r)
            }
            var s = z0 + 0.5
            while s < z1 {
                let sleeper = SCNBox(width: 1.6, height: 0.06, length: 0.3, chamferRadius: 0)
                sleeper.materials = [sleeperMat]
                let sl = SCNNode(geometry: sleeper)
                sl.position = SCNVector3(x, 0.03, s)
                parent.addChildNode(sl)
                s += 1.4
            }
        }
        // overhead light every ~8 units
        var lz = z0 + 4
        while lz < z1 {
            let lamp = SCNBox(width: 2.5, height: 0.15, length: 0.8, chamferRadius: 0.05)
            lamp.materials = [lightMat]
            let l = SCNNode(geometry: lamp)
            l.position = SCNVector3(0, 5.8, lz)
            parent.addChildNode(l)
            lz += 8
        }
    }

    private enum Pattern {
        case coinLine, coinArc, barrierRow, lowAndHigh, trainPair, trainCenter, signGates, empty
    }

    private func pickPattern(distance: Double) -> Pattern {
        let d = distance
        var weights: [(Pattern, Int)] = [(.coinLine, 30), (.empty, 15), (.barrierRow, 20), (.lowAndHigh, 15), (.signGates, 12)]
        if d > 150 { weights += [(.coinArc, 15), (.trainPair, 12), (.trainCenter, 12)] }
        let total = weights.reduce(0) { $0 + $1.1 }
        var r = Int.random(in: 0..<total)
        for (p, w) in weights { r -= w; if r < 0 { return p } }
        return .coinLine
    }

    private func addToken(x: Float, y: Float = 0.6, z: Float, into parent: SCNNode) {
        let t = Collectible(kind: .token)
        t.node.position = SCNVector3(x, y, z)
        parent.addChildNode(t.node)
        collectibles.append(t)
    }

    private func addObstacle(_ kind: ObstacleKind, lane: Int, z: Float, into parent: SCNNode) -> Obstacle {
        let o = Obstacle(kind: kind)
        o.lane = lane
        o.node.position = SCNVector3(Self.laneX(lane), 0, z)
        parent.addChildNode(o.node)
        obstacles.append(o)
        return o
    }

    /// Spawn one gameplay chunk at z position `z` (negative = ahead).
    private func spawnChunk(at z: Float, distance: Double) -> Float {
        let chunk = SCNNode()
        root.addChildNode(chunk)
        sceneryNodes.append(chunk)
        let pattern = pickPattern(distance: distance)
        var chunkLen: Float = 18

        switch pattern {
        case .coinLine:
            let lane = Int.random(in: 0..<3)
            for i in 0..<8 { addToken(x: Self.laneX(lane), z: z - Float(i) * 2, into: chunk) }
            chunkLen = 20
        case .coinArc:
            let lane = Int.random(in: 0..<3)
            // arc of coins over a low barrier
            for i in 0..<7 {
                let t = Float(i) / 6
                let y = 0.6 + 2.4 * 4 * t * (1 - t) * 0.55
                addToken(x: Self.laneX(lane), y: y, z: z - Float(i) * 1.6 - 4, into: chunk)
            }
            _ = addObstacle(.lowBarrier, lane: lane, z: z - 8.8, into: chunk)
            chunkLen = 22
        case .barrierRow:
            // barriers in 2 lanes, third lane free (or jumpable)
            let free = Int.random(in: 0..<3)
            for lane in 0..<3 where lane != free {
                _ = addObstacle([.lowBarrier, .fullBarrier, .signpost].randomElement()!, lane: lane, z: z - 8, into: chunk)
            }
            for i in 0..<4 { addToken(x: Self.laneX(free), z: z - Float(i) * 2 - 4, into: chunk) }
            chunkLen = 20
        case .lowAndHigh:
            // low barrier in one lane (jump), high in another (roll), one free
            let lanes = [0, 1, 2].shuffled()
            _ = addObstacle(.lowBarrier, lane: lanes[0], z: z - 8, into: chunk)
            _ = addObstacle(.highBarrier, lane: lanes[1], z: z - 8, into: chunk)
            chunkLen = 20
        case .trainPair:
            // trains in two lanes, one free
            let free = Int.random(in: 0..<3)
            for lane in 0..<3 where lane != free {
                _ = addObstacle(.train, lane: lane, z: z - 14, into: chunk)
            }
            for i in 0..<6 { addToken(x: Self.laneX(free), z: z - Float(i) * 3 - 4, into: chunk) }
            chunkLen = 40
        case .trainCenter:
            // one long train center, coins on both sides
            _ = addObstacle(.train, lane: 1, z: z - 14, into: chunk)
            for i in 0..<5 {
                addToken(x: Self.laneX(0), z: z - Float(i) * 3 - 4, into: chunk)
                addToken(x: Self.laneX(2), z: z - Float(i) * 3 - 5.5, into: chunk)
            }
            chunkLen = 40
        case .signGates:
            // high barriers across 2-3 lanes (roll under) + occasional signpost
            for lane in 0..<3 {
                if lane == 2 || Bool.random() {
                    _ = addObstacle(.highBarrier, lane: lane, z: z - 8, into: chunk)
                } else {
                    _ = addObstacle(.signpost, lane: lane, z: z - 8, into: chunk)
                }
            }
            chunkLen = 20
        case .empty:
            chunkLen = 14
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

        // ground under the chunk + margin
        spawnGroundChunk(from: z - chunkLen - 4, to: z + 2, into: chunk)
        return chunkLen
    }

    // MARK: - Per-frame update

    /// Moves the world toward +z by `speed*dt`, recycles, spawns.
    /// `player` is used for collision and collection.
    func update(dt: TimeInterval, speed: Double, player: Player,
                magnetOn: Bool, jetpackOn: Bool, distance: Double) {
        let dz = Float(speed * dt)

        // move spawned chunks (each chunk is a node at z=0 with children at negative z)
        for chunk in sceneryNodes {
            chunk.position.z += dz
        }
        // recycle chunks fully past camera
        var i = 0
        while i < sceneryNodes.count {
            let c = sceneryNodes[i]
            // find min child z (most negative)
            var minZ: Float = 0
            for child in c.childNodes { minZ = min(minZ, child.position.z) }
            if c.position.z + minZ > recycleZ {
                c.removeFromParentNode()
                sceneryNodes.remove(at: i)
            } else { i += 1 }
        }
        // keep obstacle/collectible lists in sync with removed nodes (cheap: filter dead)
        obstacles.removeAll { $0.node.parent == nil }
        collectibles.removeAll { $0.node.parent == nil }

        // spawn ahead
        while nextSpawnZ > spawnAhead {
            nextSpawnZ -= spawnChunk(at: nextSpawnZ, distance: distance)
        }
        // shift the spawn cursor with the world (world moved +dz, so the
        // "ahead" frontier also moved closer to the camera in world coords)
        nextSpawnZ += dz

        // moving trains advance extra
        for o in obstacles where o.kind == .movingTrain {
            o.node.position.z += Float(speed * 0.6 * dt) // approaches faster than world speed
        }

        // animate collectibles
        for c in collectibles { c.update(dt: dt) }

        handleCollisions(player: player, magnetOn: magnetOn, jetpackOn: jetpackOn)
    }

    func reset() {
        for n in sceneryNodes { n.removeFromParentNode() }
        sceneryNodes.removeAll()
        obstacles.removeAll()
        collectibles.removeAll()
        nextSpawnZ = -20
        distanceSincePowerUp = 0
    }

    // MARK: - Collision

    private func handleCollisions(player: Player, magnetOn: Bool, jetpackOn: Bool) {
        let hb = player.hitbox()
        let px = player.node.position.x

        // collectibles
        for c in collectibles where !c.collected {
            let wp = c.node.worldPosition
            let dx = abs(wp.x - px)
            let dz = abs(wp.z - 0) // player at z=0
            switch c.kind {
            case .token:
                // magnet pulls tokens
                if magnetOn, dx < 4, abs(wp.z) < 8 {
                    let dir = SCNVector3(px - wp.x, 0, -wp.z)
                    let len = max(0.01, sqrt(dir.x * dir.x + dir.z * dir.z))
                    let pull: Float = 12 * Float(1.0 / 60)
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
            // player ~1 unit deep at z=0
            let overlapZ = oz0 < 0.5 && oz1 > -0.5
            let dx = abs(wp.x - px)
            let overlapX = dx < o.halfW + hb.halfW

            // landed on top of a train?
            if o.kind == .train, overlapX, overlapZ || (wp.z - o.length/2 < 0 && wp.z + o.length/2 > 0) {
                let feetY = player.node.position.y
                if feetY >= o.trainTopHeight - 0.4, player.isJumping || player.visualY > 0 || player.onTrainTop {
                    landedOnTrain = true
                    player.onTrainTop = true
                    player.trainTopY = o.trainTopHeight
                }
            }

            guard overlapZ, overlapX else {
                // train dodged tracking: train fully passed player
                if !o.scored, o.kind == .train || o.kind == .movingTrain, wp.z - o.length / 2 > 0.5 {
                    o.scored = true
                    onTrainDodged?()
                }
                // cleared low barrier while jumping
                if !o.scored, o.kind == .lowBarrier, wp.z > 0.5 {
                    o.scored = true
                    if player.isJumping { onBarrierJumped?() }
                }
                if !o.scored, o.kind == .highBarrier, wp.z > 0.5 {
                    o.scored = true
                    if player.isRolling { onSignRolled?() }
                }
                continue
            }

            if jetpackOn { continue } // flying over everything

            let yOverlap = hb.maxY > o.minY + o.node.worldPosition.y && hb.minY < o.maxY + o.node.worldPosition.y
            guard yOverlap else { continue }

            switch o.kind {
            case .lowBarrier:
                if player.isJumping { continue }
                hit(o, player: player, dx: dx)
            case .highBarrier:
                if player.isRolling { continue }
                hit(o, player: player, dx: dx)
            case .train:
                if player.onTrainTop { continue }
                hit(o, player: player, dx: dx)
            case .movingTrain, .fullBarrier, .signpost:
                hit(o, player: player, dx: dx)
            }
        }
        if !landedOnTrain { player.onTrainTop = false }
    }

    private func hit(_ o: Obstacle, player: Player, dx: Float) {
        // side graze: player mid lane-change overlapping edge -> stumble
        let edge = dx > o.halfW - 0.15
        if edge {
            o.node.position.z += Float(2) // push past so we don't retrigger
            player.stumble()
            onStumble?()
        } else {
            onCrash?(o.kind)
        }
    }
}
