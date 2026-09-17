import SwiftUI

struct RootView: View {
    @StateObject private var gameState = GameState()

    var body: some View {
        ZStack {
            switch gameState.phase {
            case .menu:
                MenuView()
            case .playing, .paused, .gameOver:
                GameView()
            }
            if gameState.phase == .gameOver {
                GameOverView()
            }
            if gameState.phase == .paused {
                PauseView()
            }
        }
        .environmentObject(gameState)
        .statusBarHidden(true)
    }
}
