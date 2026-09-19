import Combine
@preconcurrency import SceneKit
import XCTest

@preconcurrency @testable import DevinSurfers

final class GameLoopThreadingTests: XCTestCase {
    @MainActor
    func testRenderCallbacksPublishOnMainThreadAcrossRepeatedPauses() async {
        let state = GameState()
        let game = GameScene(state: state)
        let renderer = SCNRenderer(device: nil, options: nil)
        let subscription = state.objectWillChange.sink {
            XCTAssertTrue(Thread.isMainThread)
        }
        defer { subscription.cancel() }

        state.startRun()
        await renderFrame(game, renderer: renderer, time: 1)
        for frame in 1...20 {
            let time = 1 + Double(frame) / 10
            let previousDistance = state.distance
            await renderFrame(game, renderer: renderer, time: time)
            XCTAssertGreaterThan(state.distance, previousDistance)
            game.tapPause()
            XCTAssertEqual(state.phase, .paused)
            let pausedDistance = state.distance
            await renderFrame(game, renderer: renderer, time: time + 0.05)
            XCTAssertEqual(state.distance, pausedDistance)
            game.tapPause()
            XCTAssertEqual(state.phase, .playing)
        }
        XCTAssertGreaterThan(state.score, 0)
    }

    private func renderFrame(_ game: GameScene, renderer: SCNRenderer, time: TimeInterval) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInteractive).async {
                game.renderer(renderer, updateAtTime: time)
                DispatchQueue.main.async {
                    continuation.resume()
                }
            }
        }
    }

    @MainActor
    func testDeathStopsFramesAndStaleDeathCannotEndRestartedRun() async {
        let state = GameState()
        let game = GameScene(state: state)
        let renderer = SCNRenderer(device: nil, options: nil)
        state.startRun()
        await renderFrame(game, renderer: renderer, time: 1)
        game.track.onCrash?(.train)
        game.track.onCrash?(.train)
        XCTAssertTrue(game.player.isDead)
        let distance = state.distance
        await renderFrame(game, renderer: renderer, time: 1.1)
        XCTAssertEqual(state.distance, distance)
        state.phase = .menu
        state.startRun()
        let settled = expectation(description: "Death callback elapsed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { settled.fulfill() }
        await fulfillment(of: [settled], timeout: 3)
        XCTAssertEqual(state.phase, .playing)
        XCTAssertNil(state.dyingText)
        XCTAssertFalse(game.player.isDead)
    }
}
