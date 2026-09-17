import SwiftUI

struct MenuView: View {
    @EnvironmentObject var state: GameState

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: ArcadeTheme.ink.opacity(0.2), location: 0),
                    .init(color: .clear, location: 0.4),
                    .init(color: .clear, location: 0.63),
                    .init(color: ArcadeTheme.ink, location: 0.82),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                title
                    .padding(.top, 22)

                Spacer(minLength: 24)

                VStack(spacing: 14) {
                    HStack(spacing: 6) {
                        Circle().fill(ArcadeTheme.mint).frame(width: 6, height: 6)
                        Text("DEVIN THE OTTER")
                            .tracking(2)
                        Text("/ READY TO RUN")
                            .foregroundStyle(ArcadeTheme.muted)
                    }
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(ArcadeTheme.mint)

                    Button(action: state.startRun) {
                        HStack {
                            Image(systemName: "play.fill")
                            Spacer()
                            Text("LET’S RUN")
                                .tracking(2)
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .padding(.horizontal, 22)
                    }
                    .buttonStyle(ArcadeButtonStyle())
                    .keyboardShortcut(.return, modifiers: [])
                    .accessibilityLabel("Play Running from AI Slop")

                    HStack(spacing: 10) {
                        MenuTile(
                            title: "MISSIONS", detail: "\(state.missions.count) active", icon: "scope",
                            color: ArcadeTheme.mint
                        ) {
                            state.showMissions = true
                        }
                        MenuTile(
                            title: "BEST RUN", detail: state.highScore.formatted(), icon: "trophy.fill",
                            color: ArcadeTheme.gold
                        ) {
                            state.showTopRun = true
                        }
                        MenuTile(title: "HOW TO", detail: "Learn the moves", icon: "hand.draw.fill", color: .white) {
                            state.showHowToPlay = true
                        }
                    }
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
        }
        .sheet(isPresented: $state.showMissions) { missionsSheet }
        .sheet(isPresented: $state.showTopRun) { topRunSheet }
        .sheet(isPresented: $state.showHowToPlay) { howToPlaySheet }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("devin")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .tracking(-1)
                Text("ARCADE")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(ArcadeTheme.mint)
            }
            Spacer()
            HStack(spacing: 9) {
                ACUTokenIcon()
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.totalTokens.formatted())
                        .font(.system(.subheadline, design: .rounded, weight: .black))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("ACU TOKENS")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(ArcadeTheme.muted)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .modifier(ArcadePanel())
            .accessibilityElement(children: .combine)
        }
        .foregroundStyle(.white)
    }

    private var title: some View {
        VStack(spacing: 0) {
            Text("RUNNING FROM")
                .font(.system(size: 23, weight: .black, design: .rounded))
                .tracking(3)
                .foregroundStyle(.white)
            Text("AI SLOP")
                .font(.system(size: 68, weight: .black, design: .rounded))
                .tracking(-3)
                .foregroundStyle(
                    LinearGradient(colors: [ArcadeTheme.gold, ArcadeTheme.orange], startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: Color(red: 0.55, green: 0.23, blue: 0.04), radius: 0, x: 0, y: 4)
            Text("Outrun the noise. Collect the ACU.")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(ArcadeTheme.muted)
                .padding(.top, 7)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .combine)
    }

    private var missionsSheet: some View {
        ArcadeSheet(title: "Your missions", subtitle: "RUNNING FROM AI SLOP") {
            state.showMissions = false
        } content: {
            HStack {
                ACUTokenIcon()
                Text("+100 ACU for every mission completed")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
            }
            .foregroundStyle(ArcadeTheme.gold)
            ForEach(state.missions) { mission in
                MissionProgressRow(mission: mission)
                    .padding(18)
                    .modifier(ArcadePanel())
            }
        }
    }

    private var topRunSheet: some View {
        ArcadeSheet(title: "Personal best", subtitle: "THE RUN TO BEAT") {
            state.showTopRun = false
        } content: {
            Image(systemName: "trophy.fill")
                .font(.system(size: 64))
                .foregroundStyle(ArcadeTheme.gold)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
            Text(state.highScore.formatted())
                .font(.system(size: 64, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity)
            HStack(spacing: 12) {
                RunStat(title: "ACU BANKED", value: state.totalTokens.formatted(), icon: "circle.fill")
                RunStat(
                    title: "BOARDS", value: state.hoverboardCharges.formatted(), icon: "shield.fill",
                    color: ArcadeTheme.mint)
            }
        }
    }

    private var howToPlaySheet: some View {
        ArcadeSheet(title: "Make your escape", subtitle: "FOUR MOVES. NO SLOP.") {
            state.showHowToPlay = false
        } content: {
            controlRow(
                icon: "arrow.left.arrow.right", title: "Switch lanes", detail: "Swipe left or right to dodge trains.")
            controlRow(icon: "arrow.up", title: "Jump", detail: "Swipe up to clear low barriers.")
            controlRow(icon: "arrow.down", title: "Roll", detail: "Swipe down to duck under signs.")
            controlRow(
                icon: "hand.tap.fill", title: "Ride a hoverboard",
                detail: "Double-tap or tap the shield. Blocks one crash.")
            Label("Simulator: arrows to move · Space for board · P to pause", systemImage: "keyboard")
                .font(.footnote)
                .foregroundStyle(ArcadeTheme.muted)
                .padding(.top, 8)
        }
    }

    private func controlRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2.bold())
                .foregroundStyle(ArcadeTheme.mint)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(.headline, design: .rounded, weight: .bold))
                Text(detail).font(.subheadline).foregroundStyle(ArcadeTheme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .modifier(ArcadePanel())
    }
}

private struct MenuTile: View {
    let title: String
    let detail: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundStyle(color)
                Text(title).font(.system(size: 10, weight: .heavy, design: .rounded))
                Text(detail).font(.system(size: 9, weight: .medium, design: .rounded)).foregroundStyle(
                    ArcadeTheme.muted)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: 80)
            .foregroundStyle(.white)
            .modifier(ArcadePanel())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

private struct ArcadeSheet<Content: View>: View {
    let title: String
    let subtitle: String
    let dismiss: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(subtitle)
                            .font(.system(.caption2, design: .rounded, weight: .heavy))
                            .tracking(2)
                            .foregroundStyle(ArcadeTheme.mint)
                        Text(title).font(.system(.title, design: .rounded, weight: .black))
                    }
                    Spacer()
                    Button(action: dismiss) {
                        Image(systemName: "xmark").font(.headline.bold()).frame(width: 44, height: 44)
                    }
                    .background(ArcadeTheme.panel, in: Circle())
                    .accessibilityLabel("Close")
                }
                .padding(.vertical, 12)
                content()
            }
            .padding(24)
        }
        .foregroundStyle(.white)
        .background(ArcadeTheme.ink)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
