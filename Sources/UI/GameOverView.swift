import SwiftUI

struct GameOverView: View {
    @EnvironmentObject var state: GameState

    var body: some View {
        ZStack {
            ArcadeTheme.ink.opacity(0.94).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 10) {
                        Image(systemName: state.newHighScore ? "trophy.fill" : "flag.checkered")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(ArcadeTheme.gold)
                        Text(state.newHighScore ? "NEW PERSONAL BEST" : "RUN COMPLETE")
                            .font(.system(.caption, design: .rounded, weight: .heavy))
                            .tracking(3)
                            .foregroundStyle(ArcadeTheme.mint)
                        Text("Nice run, Devin.")
                            .font(.system(.largeTitle, design: .rounded, weight: .black))
                        Text(state.deathCause)
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(ArcadeTheme.muted)
                    }

                    VStack(spacing: 4) {
                        Text(state.score.formatted())
                            .font(.system(size: 72, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text("TOTAL SCORE")
                            .font(.system(.caption2, design: .rounded, weight: .heavy))
                            .tracking(3)
                            .foregroundStyle(ArcadeTheme.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .modifier(ArcadePanel())

                    HStack(spacing: 12) {
                        RunStat(title: "ACU COLLECTED", value: state.tokens.formatted(), icon: "circle.fill")
                        RunStat(
                            title: "METERS RUN", value: Int(state.distance).formatted(), icon: "figure.run",
                            color: ArcadeTheme.mint)
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Text("MISSIONS")
                                .tracking(2)
                            Spacer()
                            Text("+100 ACU EACH")
                                .foregroundStyle(ArcadeTheme.gold)
                        }
                        .font(.system(.caption2, design: .rounded, weight: .heavy))
                        ForEach(state.missions) { mission in
                            MissionProgressRow(mission: mission)
                        }
                    }
                    .padding(18)
                    .modifier(ArcadePanel())
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 12) {
                    Button(action: state.startRun) {
                        Label("RUN AGAIN", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(ArcadeButtonStyle())
                    .keyboardShortcut(.return, modifiers: [])
                    Button(action: { state.phase = .menu }) {
                        Text("BACK TO MENU")
                    }
                    .buttonStyle(ArcadeButtonStyle(primary: false))
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 12)
                .background(ArcadeTheme.ink)
            }
        }
        .foregroundStyle(.white)
    }
}

struct PauseView: View {
    @EnvironmentObject var state: GameState

    var body: some View {
        ZStack {
            ArcadeTheme.ink.opacity(0.92).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(ArcadeTheme.mint)
                        .frame(width: 76, height: 76)
                        .modifier(ArcadePanel())
                    VStack(spacing: 10) {
                        Text("Take a breather.")
                            .font(.system(.largeTitle, design: .rounded, weight: .black))
                        Text("Devin’s ready when you are.")
                            .font(.subheadline)
                            .foregroundStyle(ArcadeTheme.muted)
                    }
                    HStack(spacing: 12) {
                        RunStat(title: "SCORE", value: state.score.formatted(), icon: "star.fill")
                        RunStat(title: "ACU TOKENS", value: state.tokens.formatted(), icon: "circle.fill")
                    }
                    Button(action: { state.phase = .playing }) {
                        Label("KEEP RUNNING", systemImage: "play.fill")
                    }
                    .buttonStyle(ArcadeButtonStyle())
                    .keyboardShortcut(.return, modifiers: [])
                    Button(action: { state.phase = .menu }) {
                        Text("QUIT TO MENU")
                    }
                    .buttonStyle(ArcadeButtonStyle(primary: false))
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.vertical, 44)
            }
            .defaultScrollAnchor(.center)
        }
        .foregroundStyle(.white)
    }
}
