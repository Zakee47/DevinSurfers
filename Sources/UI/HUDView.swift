import SwiftUI

struct HUDView: View {
    @EnvironmentObject var state: GameState
    private let gold = Color(red: 0.961, green: 0.773, blue: 0.094)

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(state.score)")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(radius: 4)
                    if state.multiplier > 1 {
                        Text("×\(state.multiplier)")
                            .font(.headline.bold())
                            .foregroundColor(.purple)
                    }
                    Text("\(Int(state.distance))m")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.leading)
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle().fill(gold).frame(width: 18, height: 18)
                            .overlay(Text("A").font(.caption2.bold()).foregroundColor(.black))
                        Text("\(state.tokens)")
                            .font(.title2.bold().monospacedDigit())
                            .foregroundColor(gold)
                    }
                    // power-up timers
                    ForEach(PowerUpKind.allCases, id: \.self) { kind in
                        if let remaining = state.activePowerUps[kind], kind != .hoverboardPickup {
                            PowerUpBar(kind: kind, remaining: remaining)
                        }
                    }
                    if state.hoverboardActive {
                        PowerUpBar(kind: .hoverboardPickup,
                                   remaining: state.activePowerUps[.hoverboardPickup] ?? 0)
                    }
                    Button(action: { state.phase = .paused }) {
                        Image(systemName: "pause.fill")
                            .font(.title3)
                            .padding(10)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                            .foregroundColor(.white)
                    }
                }
                .padding(.trailing)
            }
            .padding(.top, 8)

            if state.stumbleFlash {
                Text("STUMBLE! AI Slop is behind you!")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.red.opacity(0.85))
                    .clipShape(Capsule())
                    .transition(.scale)
            }
            Spacer()
        }
        .animation(.default, value: state.stumbleFlash)
    }
}

struct PowerUpBar: View {
    let kind: PowerUpKind
    let remaining: TimeInterval

    var body: some View {
        let total: TimeInterval = kind == .hoverboardPickup ? 30 : kind.duration
        let frac = max(0, min(1, remaining / total))
        HStack(spacing: 4) {
            Text(kind.displayName).font(.caption2.bold())
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.2)).frame(width: 60, height: 6)
                Capsule().fill(Color.green).frame(width: 60 * frac, height: 6)
            }
        }
        .foregroundColor(.white)
    }
}
