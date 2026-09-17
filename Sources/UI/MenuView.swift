import SwiftUI

struct MenuView: View {
    @EnvironmentObject var state: GameState
    @FocusState private var playFocused: Bool

    private let devinBlue = Color(red: 0.118, green: 0.388, blue: 1.0)
    private let gold = Color(red: 0.961, green: 0.773, blue: 0.094)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.03, green: 0.04, blue: 0.12), devinBlue.opacity(0.35)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                Text("RUNNING FROM\nAI SLOP")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(LinearGradient(colors: [devinBlue, gold], startPoint: .leading, endPoint: .trailing))
                    .shadow(color: devinBlue.opacity(0.6), radius: 12)
                Text("Devin the otter — endless runner")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))

                Button(action: { state.startRun() }) {
                    Text("▶  PLAY")
                        .font(.title2.bold())
                        .padding(.horizontal, 60)
                        .padding(.vertical, 14)
                        .background(gold)
                        .foregroundColor(.black)
                        .clipShape(Capsule())
                }
                .focused($playFocused)
                .onAppear { playFocused = true }
                // Return key triggers Play on simulator
                .keyboardShortcut(.return, modifiers: [])

                HStack(spacing: 30) {
                    VStack {
                        Text("HIGH SCORE").font(.caption).foregroundColor(.white.opacity(0.6))
                        Text("\(state.highScore)").font(.title3.bold()).foregroundColor(gold)
                    }
                    VStack {
                        Text("ACU TOKENS").font(.caption).foregroundColor(.white.opacity(0.6))
                        Text("\(state.totalTokens)").font(.title3.bold()).foregroundColor(gold)
                    }
                    VStack {
                        Text("HOVERBOARDS").font(.caption).foregroundColor(.white.opacity(0.6))
                        Text("\(state.hoverboardCharges)").font(.title3.bold()).foregroundColor(devinBlue)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("MISSIONS — Running from AI Slop")
                        .font(.headline)
                        .foregroundColor(.white)
                    ForEach(state.missions) { m in
                        HStack {
                            Text(m.title).font(.subheadline).foregroundColor(.white.opacity(0.9))
                            Spacer()
                            Text("\(m.progress)/\(m.goal)").font(.subheadline.monospacedDigit()).foregroundColor(gold)
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                VStack(spacing: 4) {
                    Text("HOW TO PLAY").font(.caption.bold()).foregroundColor(.white.opacity(0.6))
                    Text("Swipe ← → to switch lanes · Swipe ↑ to jump · Swipe ↓ to roll\nDouble-tap for hoverboard · Keys: arrows, space, P")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
            }
        }
    }
}
