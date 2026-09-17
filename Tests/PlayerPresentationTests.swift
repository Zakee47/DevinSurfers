import SceneKit
import SwiftUI
import XCTest

@testable import DevinSurfers

final class PlayerPresentationTests: XCTestCase {
    private func forward(_ player: Player) -> SCNVector3 {
        player.bodyNode.convertVector(SCNVector3(0, 0, 1), to: nil)
    }

    func testFacesDownTrackAcrossMovementAndPowerUps() {
        let player = Player()
        XCTAssertLessThan(forward(player).z, -0.99)
        player.moveLane(dir: 1)
        XCTAssertTrue(player.jump())
        for _ in 0..<90 {
            player.update(dt: 1.0 / 60, speed: 12, flying: false, groundY: 0)
            XCTAssertLessThan(forward(player).z, -0.99)
        }
        XCTAssertEqual(player.node.position.x, TrackManager.laneX(2), accuracy: 0.001)
        XCTAssertFalse(player.isJumping)

        XCTAssertTrue(player.roll())
        player.update(dt: 0.1, speed: 12, flying: false, groundY: 0)
        XCTAssertLessThan(forward(player).z, -0.99)
        player.setJetpackVisual(true)
        player.update(dt: 0.1, speed: 12, flying: true, groundY: 0)
        XCTAssertLessThan(forward(player).z, -0.8)
        XCTAssertGreaterThan(player.jetpackNode!.worldPosition.z, player.node.worldPosition.z)
    }

    func testPresentationResetClearsDeathAndMovementWithoutTurningRunnerBackwards() {
        let player = Player()
        player.moveLane(dir: -1)
        player.update(dt: 0.2, speed: 12, flying: false, groundY: 0)
        XCTAssertTrue(player.roll())
        player.stumble()
        player.setJetpackVisual(true)
        player.setSneakersVisual(true)
        player.die()
        player.prepareForMenu()
        XCTAssertGreaterThan(forward(player).z, 0.9)
        XCTAssertFalse(player.node.hasActions)
        XCTAssertFalse(player.isDead)
        XCTAssertFalse(player.isRolling)
        XCTAssertFalse(player.isStumbling)
        XCTAssertNil(player.jetpackNode)
        XCTAssertNil(player.sneakersNode)

        player.prepareForRun()
        XCTAssertLessThan(forward(player).z, -0.99)
        XCTAssertEqual(player.node.position.x, 0)
        XCTAssertEqual(player.node.position.y, 0)
        XCTAssertTrue(player.jump())
        player.update(dt: 0.1, speed: 12, flying: false, groundY: 0)
        XCTAssertGreaterThan(player.node.position.y, 0)
    }

    @MainActor
    func testRestartAfterDeathAndReturnFromMenuRestoreRunPresentation() throws {
        let state = GameState()
        let game = GameScene(state: state)
        XCTAssertGreaterThan(forward(game.player).z, 0.9)
        XCTAssertTrue(game.track.root.isHidden)
        try attachPresentation(game, name: "Menu")
        state.startRun()
        XCTAssertLessThan(forward(game.player).z, -0.99)
        XCTAssertFalse(game.track.root.isHidden)
        XCTAssertGreaterThan(game.track.root.boundingBox.max.z, game.player.node.position.z)
        game.track.update(dt: 0, speed: 12, player: game.player, magnetOn: false, jetpackOn: false, distance: 0)
        try attachPresentation(game, name: "Forward-facing run")

        game.player.die()
        state.distance = 150
        state.phase = .gameOver
        state.startRun()
        XCTAssertFalse(game.player.isDead)
        XCTAssertFalse(game.player.node.hasActions)
        XCTAssertLessThan(forward(game.player).z, -0.99)

        state.distance = 10
        state.phase = .paused
        state.phase = .playing
        XCTAssertEqual(state.distance, 10)
        XCTAssertLessThan(forward(game.player).z, -0.99)
        state.phase = .menu
        XCTAssertGreaterThan(forward(game.player).z, 0.9)
        state.startRun()
        XCTAssertLessThan(forward(game.player).z, -0.99)
    }

    @MainActor
    private func attachPresentation(_ game: GameScene, name: String) throws {
        let size = CGSize(width: 393, height: 852)
        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = game.scene
        renderer.pointOfView = try XCTUnwrap(game.scene.rootNode.childNodes.first { $0.camera != nil })
        let background = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        let imageRenderer = ImageRenderer(
            content: ZStack {
                Image(uiImage: background)
                Group {
                    switch game.state.phase {
                    case .menu: MenuView()
                    case .playing: HUDView(onHoverboardTap: {})
                    case .paused: PauseView()
                    case .gameOver: GameOverView()
                    }
                }
                .padding(.top, 59)
                .padding(.bottom, 34)
            }
            .frame(width: size.width, height: size.height)
            .environmentObject(game.state)
            .environment(\.colorScheme, .dark)
        )
        imageRenderer.scale = 2
        let attachment = XCTAttachment(image: try XCTUnwrap(imageRenderer.uiImage))
        attachment.name = "\(name) — offscreen render"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
