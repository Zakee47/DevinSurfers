import SwiftUI

struct HUDView: View {
    @EnvironmentObject var state: GameState
    private let gold = Color(red: 0.961, green: 0.773, blue: 0.094)
    var onHoverboardTap: (() -> Void)?

    var body: some View {
        if state.phase == .playing || state.phase == .paused {
            VStack {
                HStack(alignment: .top) {
                    // top-left round pause button
                    Button(action: { state.phase = .paused }) {
                        Image(systemName: "pause.fill")
                            .font(.title3)
                            .padding(12)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                            .foregroundColor(.white)
                    }
                    .padding(.leading, 14)
                    .padding(.top, 10)

                    // top-center power-up bars
                    VStack(spacing: 4) {
                        ForEach(PowerUpKind.allCases, id: \.self) { kind in
                            if let remaining = state.activePowerUps[kind], kind != .hoverboardPickup {
                                PowerUpBar(kind: kind, remaining: remaining)
                            }
                        }
                        if state.hoverboardActive {
                            PowerUpBar(kind: .hoverboardPickup,
                                       remaining: state.activePowerUps[.hoverboardPickup] ?? 0)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 14)

                    // top-right score + tokens
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 6) {
                            if state.multiplier > 1 {
                                Text("x\(state.multiplier)")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.purple)
                                    .clipShape(Capsule())
                            }
                            Text("\(state.score)")
                                .font(.system(size: 30, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }
                        HStack(spacing: 5) {
                            Circle().fill(gold).frame(width: 14, height: 14)
                                .overlay(Text("A").font(.system(size: 9).bold()).foregroundColor(.black))
                            Text("\(state.tokens)")
                                .font(.headline.bold().monospacedDigit())
                                .foregroundColor(gold)
                        }
                        Text("\(Int(state.distance))m")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .shadow(radius: 4)
                    .padding(.trailing, 14)
                    .padding(.top, 10)
                }

                if state.stumbleFlash {
                    Text("STUMBLE! AI Slop is behind you!")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.red.opacity(0.85))
                        .clipShape(Capsule())
                }

                Spacer()

                HStack(alignment: .bottom) {
                    // mission toast bottom-left
                    if let toast = state.missionToast {
                        Text(toast)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    Spacer()
                    // hoverboard button bottom-right
                    Button(action: { state.hoverboardRequest = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "skateboard.fill")
                                .foregroundColor(.teal)
                            Text("×\(state.hoverboardCharges)")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                        }
                        .padding(10)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Capsule())
                    }
                    .padding(.trailing, 14)
                }
                .padding(.leading, 14)
                .padding(.bottom, 14)
            }
            .animation(.default, value: state.stumbleFlash)
            .animation(.default, value: state.missionToast)
        }
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
                Capsule().fill(Color.white.opacity(0.25)).frame(width: 70, height: 6)
                Capsule().fill(Color.green).frame(width: 70 * frac, height: 6)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.4))
        .clipShape(Capsule())
    }
}
