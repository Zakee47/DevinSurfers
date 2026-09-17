import SwiftUI

struct GameOverView: View {
    @EnvironmentObject var state: GameState
    private let gold = Color(red: 0.961, green: 0.773, blue: 0.094)
    private let devinBlue = Color(red: 0.118, green: 0.388, blue: 1.0)

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(state.deathCause)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(.red)

                // results card
                VStack(spacing: 12) {
                    if state.newHighScore {
                        Text("NEW HIGH SCORE!")
                            .font(.headline.bold())
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                            .background(gold)
                            .clipShape(Capsule())
                    }
                    Text("SCORE").font(.caption).foregroundColor(.secondary)
                    Text("\(state.score)")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                    HStack(spacing: 24) {
                        Label("\(state.tokens)", systemImage: "circle.fill")
                            .foregroundColor(gold)
                        Label("\(Int(state.distance))m", systemImage: "figure.run")
                    }
                    .font(.subheadline.bold())

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("MISSIONS").font(.caption.bold()).foregroundColor(.secondary)
                        ForEach(state.missions) { m in
                            HStack {
                                Text(m.title).font(.caption)
                                Spacer()
                                Text("\(m.progress)/\(m.goal)").font(.caption.monospacedDigit()).foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 30)

                Button(action: { state.startRun() }) {
                    Text("PLAY AGAIN")
                        .font(.title3.bold())
                        .padding(.horizontal, 50)
                        .padding(.vertical, 14)
                        .background(gold)
                        .foregroundColor(.black)
                        .clipShape(Capsule())
                }
                Button(action: { state.phase = .menu }) {
                    Text("MENU")
                        .font(.headline.bold())
                        .padding(.horizontal, 40)
                        .padding(.vertical, 10)
                        .background(devinBlue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
        }
    }
}

struct PauseView: View {
    @EnvironmentObject var state: GameState
    private let gold = Color(red: 0.961, green: 0.773, blue: 0.094)

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("PAUSED")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Button(action: { state.phase = .playing }) {
                    Text("RESUME").font(.headline.bold())
                        .padding(.horizontal, 40).padding(.vertical, 12)
                        .background(gold).foregroundColor(.black).clipShape(Capsule())
                }
                Button(action: { state.phase = .menu }) {
                    Text("QUIT TO MENU").font(.subheadline.bold())
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
}
