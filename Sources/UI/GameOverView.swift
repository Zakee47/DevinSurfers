import SwiftUI

struct GameOverView: View {
    @EnvironmentObject var state: GameState
    private let gold = Color(red: 0.961, green: 0.773, blue: 0.094)
    private let devinBlue = Color(red: 0.118, green: 0.388, blue: 1.0)

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 18) {
                Text(state.deathCause)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(.red)
                if state.newHighScore {
                    Text("🏆 NEW HIGH SCORE!")
                        .font(.headline.bold())
                        .foregroundColor(gold)
                }
                VStack(spacing: 6) {
                    Text("SCORE").font(.caption).foregroundColor(.white.opacity(0.6))
                    Text("\(state.score)").font(.system(size: 48, weight: .black)).foregroundColor(.white)
                    HStack(spacing: 24) {
                        Label("\(state.tokens) tokens", systemImage: "circle.fill")
                            .foregroundColor(gold)
                        Label("\(Int(state.distance))m", systemImage: "figure.run")
                            .foregroundColor(.white.opacity(0.8))
                    }.font(.subheadline)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("MISSIONS").font(.caption.bold()).foregroundColor(.white.opacity(0.6))
                    ForEach(state.missions) { m in
                        HStack {
                            Text(m.title).font(.caption).foregroundColor(.white.opacity(0.85))
                            Spacer()
                            Text("\(m.progress)/\(m.goal)").font(.caption.monospacedDigit()).foregroundColor(gold)
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 40)

                HStack(spacing: 16) {
                    Button(action: { state.startRun() }) {
                        Text("RETRY").font(.headline.bold())
                            .padding(.horizontal, 30).padding(.vertical, 12)
                            .background(gold).foregroundColor(.black).clipShape(Capsule())
                    }
                    Button(action: { state.phase = .menu }) {
                        Text("MENU").font(.headline.bold())
                            .padding(.horizontal, 30).padding(.vertical, 12)
                            .background(devinBlue).foregroundColor(.white).clipShape(Capsule())
                    }
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
