import Foundation
import Combine

enum GamePhase {
    case menu, playing, paused, gameOver
}

enum PowerUpKind: String, CaseIterable {
    case magnet, jetpack, superSneakers, multiplier2x, hoverboardPickup

    var duration: TimeInterval {
        switch self {
        case .magnet: return 10
        case .jetpack: return 8
        case .superSneakers: return 10
        case .multiplier2x: return 15
        case .hoverboardPickup: return 0
        }
    }

    var displayName: String {
        switch self {
        case .magnet: return "Magnet"
        case .jetpack: return "Jetpack"
        case .superSneakers: return "Sneakers"
        case .multiplier2x: return "2x Score"
        case .hoverboardPickup: return "Hoverboard"
        }
    }
}

final class GameState: ObservableObject {
    @Published var phase: GamePhase = .menu
    @Published var score: Int = 0
    @Published var tokens: Int = 0
    @Published var distance: Double = 0
    @Published var multiplier: Int = 1
    @Published var activePowerUps: [PowerUpKind: TimeInterval] = [:]
    @Published var hoverboardActive: Bool = false
    @Published var hoverboardCharges: Int = 1
    @Published var highScore: Int = 0
    @Published var totalTokens: Int = 0
    @Published var missions: [Mission] = []
    @Published var chaserPresent: Bool = false
    @Published var stumbleFlash: Bool = false
    @Published var newHighScore: Bool = false
    @Published var deathCause: String = "CAUGHT BY AI SLOP"

    private let defaults = UserDefaults.standard
    private let highScoreKey = "devinsurfers.highScore"
    private let totalTokensKey = "devinsurfers.totalTokens"
    private let hoverboardsKey = "devinsurfers.hoverboards"
    private let missionsKey = "devinsurfers.missions"

    // Run stats for missions
    var runJumps: Int = 0
    var runRolls: Int = 0
    var runTrainsDodged: Int = 0
    var runHoverboardUsed: Bool = false

    init() {
        highScore = defaults.integer(forKey: highScoreKey)
        totalTokens = defaults.integer(forKey: totalTokensKey)
        hoverboardCharges = defaults.object(forKey: hoverboardsKey) == nil ? 1 : defaults.integer(forKey: hoverboardsKey)
        missions = MissionStore.load(defaults: defaults, key: missionsKey)
        if missions.isEmpty {
            missions = MissionStore.freshMissions()
            MissionStore.save(missions, defaults: defaults, key: missionsKey)
        }
    }

    func startRun() {
        score = 0
        tokens = 0
        distance = 0
        multiplier = 1
        activePowerUps = [:]
        hoverboardActive = false
        chaserPresent = false
        stumbleFlash = false
        newHighScore = false
        runJumps = 0
        runRolls = 0
        runTrainsDodged = 0
        runHoverboardUsed = false
        phase = .playing
    }

    func endRun(cause: String) {
        deathCause = cause
        phase = .gameOver
        totalTokens += tokens
        if score > highScore {
            highScore = score
            newHighScore = true
        }
        // missions progress is ticked live; final distance tick happens in tickMissions
        persist()
    }

    func persist() {
        defaults.set(highScore, forKey: highScoreKey)
        defaults.set(totalTokens, forKey: totalTokensKey)
        defaults.set(hoverboardCharges, forKey: hoverboardsKey)
        MissionStore.save(missions, defaults: defaults, key: missionsKey)
    }

    // Called by GameScene each frame / on events
    func tick(dt: TimeInterval, speed: Double) {
        distance += speed * dt
        let mult = activePowerUps[.multiplier2x] != nil ? 2 : 1
        multiplier = mult
        score += Int((speed * dt) * Double(mult))
        var expired: [PowerUpKind] = []
        for (k, v) in activePowerUps {
            let nv = v - dt
            if nv <= 0 { expired.append(k) } else { activePowerUps[k] = nv }
        }
        for k in expired { activePowerUps.removeValue(forKey: k) }
    }

    func collectToken() {
        tokens += 1
        score += 5 * multiplier
        bumpMission(kind: .collectTokens, by: 1)
    }

    func noteJump() { runJumps += 1; bumpMission(kind: .jumpBarriers, by: 0) }
    func noteRoll() { runRolls += 1 }
    func noteBarrierJumped() { bumpMission(kind: .jumpBarriers, by: 1) }
    func noteSignRolled() { bumpMission(kind: .rollSigns, by: 1) }
    func noteTrainDodged() { runTrainsDodged += 1; bumpMission(kind: .dodgeTrains, by: 1) }
    func noteHoverboardUsed() {
        if !runHoverboardUsed { runHoverboardUsed = true; bumpMission(kind: .useHoverboard, by: 1) }
    }
    func noteDistanceMilestone() { bumpMission(kind: .runDistance, by: Int(distance)) }

    private func bumpMission(kind: MissionKind, by amount: Int) {
        var changed = false
        for i in missions.indices where missions[i].kind == kind && !missions[i].completed {
            let before = missions[i].progress
            if kind == .runDistance {
                missions[i].progress = min(missions[i].goal, amount)
            } else {
                missions[i].progress = min(missions[i].goal, missions[i].progress + amount)
            }
            if missions[i].progress != before { changed = true }
            if missions[i].progress >= missions[i].goal {
                missions[i].completed = true
                totalTokens += 100 // mission bonus
            }
        }
        if changed {
            // rotate completed missions out, new ones in
            for i in missions.indices where missions[i].completed {
                missions[i] = MissionStore.randomMission(excluding: missions.map { $0.kind })
            }
            MissionStore.save(missions, defaults: defaults, key: missionsKey)
        }
    }
}
