import SwiftUI

struct RootView: View {
    @StateObject private var gameState = GameState()

    var body: some View {
        ZStack {
            // live 3D scene is always behind everything
            GameView()

            switch gameState.phase {
            case .menu:
                MenuView()
            case .playing:
                EmptyView()
            case .paused:
                PauseView()
            case .gameOver:
                GameOverView()
            }

            // dying banner ("CAUGHT!" / "CRASHED!")
            if let banner = gameState.dyingText {
                Text(banner)
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(ArcadeTheme.gold)
                    .padding(22)
                    .background(ArcadeTheme.ink.opacity(0.92), in: RoundedRectangle(cornerRadius: 22))
                    .transition(.scale)
                    .allowsHitTesting(false)
            }
        }
        .animation(.default, value: gameState.dyingText)
        .environmentObject(gameState)
        .statusBarHidden(true)
    }
}
