import SwiftUI

struct MenuView: View {
    @EnvironmentObject var state: GameState
    private let devinBlue = Color(red: 0.118, green: 0.388, blue: 1.0)
    private let gold = Color(red: 0.961, green: 0.773, blue: 0.094)
    @State private var pulse = false

    var body: some View {
        ZStack {
            // tap anywhere to play (scene visible behind)
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { state.startRun() }

            VStack {
                // top bar: tokens / hoverboards / high score
                HStack(spacing: 16) {
                    Label("\(state.totalTokens)", systemImage: "circle.fill")
                        .foregroundColor(gold)
                    Label("\(state.hoverboardCharges)", systemImage: "skateboard.fill")
                        .foregroundColor(.teal)
                    Spacer()
                    Label("\(state.highScore)", systemImage: "trophy.fill")
                        .foregroundColor(gold)
                }
                .font(.headline.bold())
                .padding(10)
                .background(Color.black.opacity(0.35))
                .clipShape(Capsule())
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                Text("RUNNING FROM\nAI SLOP")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(LinearGradient(colors: [devinBlue, gold], startPoint: .leading, endPoint: .trailing))
                    .shadow(color: .black.opacity(0.6), radius: 8)

                Text("Devin the otter — endless runner")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .shadow(radius: 4)

                Spacer()

                Button(action: { state.startRun() }) {
                    Text("TAP TO PLAY")
                        .font(.title2.bold())
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(gold.opacity(pulse ? 0.9 : 0.6))
                        .foregroundColor(.black)
                        .clipShape(Capsule())
                        .scaleEffect(pulse ? 1.08 : 0.96)
                }
                .keyboardShortcut(.return, modifiers: [])
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }

                // bottom row of buttons
                HStack(spacing: 14) {
                    MenuPillButton(title: "MISSIONS", color: devinBlue) { state.showMissions = true }
                    MenuPillButton(title: "TOP RUN", color: devinBlue) { state.showTopRun = true }
                    MenuPillButton(title: "HOW TO PLAY", color: devinBlue) { state.showHowToPlay = true }
                }
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $state.showMissions) { missionsSheet }
        .sheet(isPresented: $state.showTopRun) { topRunSheet }
        .sheet(isPresented: $state.showHowToPlay) { howToPlaySheet }
    }

    private var missionsSheet: some View {
        NavigationStack {
            List {
                Section("Running from AI Slop") {
                    ForEach(state.missions) { m in
                        HStack {
                            Text(m.title)
                            Spacer()
                            Text("\(m.progress)/\(m.goal)").monospacedDigit().foregroundColor(.secondary)
                        }
                    }
                }
                Section {
                    Text("Complete a mission for +100 ACU Tokens.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Missions")
            .toolbar { Button("Done") { state.showMissions = false } }
        }
        .presentationDetents([.medium])
    }

    private var topRunSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 60))
                    .foregroundColor(gold)
                Text("\(state.highScore)")
                    .font(.system(size: 60, weight: .black, design: .rounded))
                Text("HIGH SCORE").foregroundColor(.secondary)
                Label("\(state.totalTokens) ACU Tokens collected", systemImage: "circle.fill")
                    .foregroundColor(gold)
                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Top Run")
            .toolbar { Button("Done") { state.showTopRun = false } }
        }
        .presentationDetents([.medium])
    }

    private var howToPlaySheet: some View {
        NavigationStack {
            List {
                Label("Swipe left/right — change lane", systemImage: "arrow.left.arrow.right")
                Label("Swipe up — jump", systemImage: "arrow.up")
                Label("Swipe down — roll", systemImage: "arrow.down")
                Label("Double-tap — hoverboard", systemImage: "skateboard.fill")
                Label("Keyboard: arrows, space = board, P = pause", systemImage: "keyboard")
            }
            .navigationTitle("How to Play")
            .toolbar { Button("Done") { state.showHowToPlay = false } }
        }
        .presentationDetents([.medium])
    }
}

struct MenuPillButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(color.opacity(0.9))
                .foregroundColor(.white)
                .clipShape(Capsule())
        }
    }
}
