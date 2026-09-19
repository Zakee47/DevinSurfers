import Foundation

enum MissionKind: String, Codable, CaseIterable {
    case collectTokens, jumpBarriers, rollSigns, dodgeTrains, runDistance, useHoverboard
}

struct Mission: Codable, Identifiable {
    var id: UUID = UUID()
    var kind: MissionKind
    var goal: Int
    var progress: Int = 0
    var completed: Bool = false

    var title: String {
        switch kind {
        case .collectTokens: return "Collect \(goal) ACU Tokens"
        case .jumpBarriers: return "Jump over \(goal) barriers"
        case .rollSigns: return "Roll under \(goal) signs"
        case .dodgeTrains: return "Dodge \(goal) trains"
        case .runDistance: return "Run \(goal)m"
        case .useHoverboard: return "Use a hoverboard"
        }
    }
}

enum MissionStore {
    static func freshMissions() -> [Mission] {
        [
            Mission(kind: .collectTokens, goal: 50),
            Mission(kind: .jumpBarriers, goal: 15),
            Mission(kind: .runDistance, goal: 1000),
        ]
    }

    static func randomMission(excluding kinds: [MissionKind]) -> Mission {
        let pool: [(MissionKind, Int)] = [
            (.collectTokens, 50), (.collectTokens, 100),
            (.jumpBarriers, 15), (.jumpBarriers, 30),
            (.rollSigns, 10), (.rollSigns, 20),
            (.dodgeTrains, 20), (.dodgeTrains, 40),
            (.runDistance, 1000), (.runDistance, 2000),
            (.useHoverboard, 1),
        ]
        let options = pool.filter { !kinds.contains($0.0) }
        let pick = options.randomElement() ?? (.collectTokens, 50)
        return Mission(kind: pick.0, goal: pick.1)
    }

    static func save(_ missions: [Mission], defaults: UserDefaults, key: String) {
        if let data = try? JSONEncoder().encode(missions) {
            defaults.set(data, forKey: key)
        }
    }

    static func load(defaults: UserDefaults, key: String) -> [Mission] {
        guard let data = defaults.data(forKey: key),
            let m = try? JSONDecoder().decode([Mission].self, from: data)
        else { return [] }
        return m
    }
}
