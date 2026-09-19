import SwiftUI

enum ArcadeTheme {
    static let ink = Color(red: 0.035, green: 0.075, blue: 0.13)
    static let panel = Color(red: 0.075, green: 0.14, blue: 0.22)
    static let muted = Color(red: 0.65, green: 0.74, blue: 0.84)
    static let orange = Color(red: 1, green: 0.63, blue: 0.25)
    static let gold = Color(red: 1, green: 0.84, blue: 0.35)
    static let mint = Color(red: 0.40, green: 0.95, blue: 0.80)
}

struct ArcadeButtonStyle: ButtonStyle {
    var primary = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .black))
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(primary ? ArcadeTheme.ink : .white)
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: primary
                                ? [ArcadeTheme.gold, ArcadeTheme.orange]
                                : [ArcadeTheme.panel, ArcadeTheme.ink],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(.white.opacity(primary ? 0.35 : 0.15), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.35), radius: 0, y: configuration.isPressed ? 1 : 4)
            .offset(y: configuration.isPressed ? 3 : 0)
            .opacity(isEnabled ? 1 : 0.45)
    }
}

struct ACUTokenIcon: View {
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [ArcadeTheme.gold, ArcadeTheme.orange], startPoint: .topLeading,
                        endPoint: .bottomTrailing))
            Circle()
                .strokeBorder(Color(red: 0.62, green: 0.31, blue: 0.05), lineWidth: 1.5)
                .padding(size * 0.12)
            Text("A")
                .font(.system(size: size * 0.48, weight: .black, design: .rounded))
                .foregroundStyle(ArcadeTheme.ink)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct ArcadePanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(ArcadeTheme.panel.opacity(0.96), in: RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(.white.opacity(0.10), lineWidth: 1)
            }
    }
}

struct MissionProgressRow: View {
    let mission: Mission

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 12) {
                Text(mission.title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text("\(mission.progress)/\(mission.goal)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(ArcadeTheme.mint)
                    .fixedSize()
            }
            ProgressView(value: Double(mission.progress), total: Double(max(1, mission.goal)))
                .tint(ArcadeTheme.mint)
                .accessibilityHidden(true)
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }
}

struct RunStat: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = ArcadeTheme.gold

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .black))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(ArcadeTheme.muted)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .modifier(ArcadePanel())
        .accessibilityElement(children: .combine)
    }
}
