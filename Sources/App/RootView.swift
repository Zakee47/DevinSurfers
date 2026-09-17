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
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundColor(.red)
                    .shadow(color: .black, radius: 8)
                    .transition(.scale)
            }
        }
        .animation(.default, value: gameState.dyingText)
        .environmentObject(gameState)
        .statusBarHidden(true)
    }
}
