import SwiftUI

struct HUDView: View {
    @EnvironmentObject var state: GameState
    var onHoverboardTap: () -> Void

    private var boardAvailable: Bool {
        !state.hoverboardActive && state.hoverboardCharges > 0 && state.dyingText == nil
    }

    var body: some View {
        if state.phase == .playing {
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Button(action: { state.phase = .paused }) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 18, weight: .black))
                            .frame(width: 48, height: 48)
                            .background(ArcadeTheme.ink.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.25), lineWidth: 1)
                            }
                    }
                    .disabled(state.dyingText != nil)
                    .accessibilityLabel("Pause run")
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("×\(state.multiplier)")
                                .font(.system(.caption, design: .rounded, weight: .black))
                                .foregroundStyle(ArcadeTheme.gold)
                            Text(state.score.formatted())
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        HStack(spacing: 6) {
                            Text("SCORE")
                            Text("·")
                            Text("\(Int(state.distance)) m")
                        }
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(ArcadeTheme.muted)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(ArcadeTheme.ink.opacity(0.9), in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "Score \(state.score), multiplier \(state.multiplier), distance \(Int(state.distance)) meters")
                }
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(PowerUpKind.allCases, id: \.self) { kind in
                            if let remaining = state.activePowerUps[kind],
                                kind != .hoverboardPickup || state.hoverboardActive
                            {
                                PowerUpBar(kind: kind, remaining: remaining)
                            }
                        }
                    }
                    Spacer(minLength: 12)
                    HStack(spacing: 8) {
                        ACUTokenIcon(size: 24)
                        Text(state.tokens.formatted())
                            .font(.system(.headline, design: .rounded, weight: .black))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ArcadeTheme.ink.opacity(0.9), in: Capsule())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(state.tokens) ACU Tokens")
                }
                .allowsHitTesting(false)

                if state.stumbleFlash {
                    Label("AI SLOP IS CLOSING IN", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(.caption, design: .rounded, weight: .black))
                        .padding(12)
                        .background(Color(red: 0.65, green: 0.13, blue: 0.11), in: Capsule())
                        .allowsHitTesting(false)
                }

                Spacer()

                HStack(alignment: .bottom, spacing: 14) {
                    if let toast = state.missionToast {
                        VStack(alignment: .leading, spacing: 5) {
                            Label("MISSION PROGRESS", systemImage: "scope")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundStyle(ArcadeTheme.mint)
                            Text(toast)
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .background(ArcadeTheme.ink.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
                        .allowsHitTesting(false)
                    }
                    Spacer(minLength: 0)
                    Button(action: onHoverboardTap) {
                        VStack(spacing: 5) {
                            HStack(spacing: 6) {
                                Image(systemName: state.hoverboardActive ? "shield.checkered" : "shield.fill")
                                    .font(.system(size: 24, weight: .bold))
                                Text("×\(state.hoverboardCharges)")
                                    .font(.system(.subheadline, design: .rounded, weight: .black))
                            }
                            Text(
                                state.hoverboardActive
                                    ? "PROTECTED" : state.hoverboardCharges > 0 ? "HOVERBOARD" : "NO BOARDS"
                            )
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .tracking(1)
                        }
                        .foregroundStyle(
                            boardAvailable || state.hoverboardActive ? ArcadeTheme.mint : ArcadeTheme.muted
                        )
                        .frame(minWidth: 88, minHeight: 66)
                        .background(ArcadeTheme.ink.opacity(0.94), in: RoundedRectangle(cornerRadius: 20))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20).strokeBorder(
                                ArcadeTheme.mint.opacity(boardAvailable ? 0.7 : 0.2), lineWidth: 1.5)
                        }
                    }
                    .disabled(!boardAvailable)
                    .accessibilityLabel(state.hoverboardActive ? "Hoverboard active" : "Activate hoverboard")
                    .accessibilityValue("\(state.hoverboardCharges) remaining")
                    .accessibilityHint("Protects against one crash")
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 10)
        }
    }
}

struct PowerUpBar: View {
    let kind: PowerUpKind
    let remaining: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(kind.displayName.uppercased())
                Spacer()
                Text("\(Int(ceil(remaining)))s").monospacedDigit()
            }
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            ProgressView(value: max(0, remaining), total: kind == .hoverboardPickup ? 30 : kind.duration)
                .tint(ArcadeTheme.mint)
        }
        .foregroundStyle(.white)
        .frame(width: 122)
        .padding(10)
        .background(ArcadeTheme.ink.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.displayName), \(Int(ceil(remaining))) seconds remaining")
    }
}
