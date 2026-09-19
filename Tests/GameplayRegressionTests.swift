import SceneKit
import XCTest

@testable import DevinSurfers

@MainActor
final class GameplayRegressionTests: XCTestCase {
    private func makeState() throws -> GameState {
        let name = "DevinSurfersTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return GameState(defaults: defaults)
    }

    func testRunRewardsAreBankedOnceAndIgnoreStaleRunIDs() throws {
        let state = try makeState()
        state.startRun()
        let firstRun = state.runID
        state.tokens = 20
        state.endRun(cause: "crash", runID: firstRun)
        state.endRun(cause: "crash", runID: firstRun)
        XCTAssertEqual(state.totalTokens, 20)

        state.startRun()
        state.tokens = 3
        state.endRun(cause: "stale crash", runID: firstRun)
        XCTAssertEqual(state.phase, .playing)
        XCTAssertEqual(state.totalTokens, 20)
        state.endRun(cause: "crash", runID: state.runID)
        XCTAssertEqual(state.totalTokens, 23)
    }

    func testDistanceMissionKeepsBestProgressAcrossRuns() throws {
        let state = try makeState()
        state.missions = [Mission(kind: .runDistance, goal: 1000)]
        state.startRun()
        state.distance = 800
        state.noteDistanceMilestone()
        state.endRun(cause: "crash", runID: state.runID)
        state.startRun()
        state.distance = 50
        state.noteDistanceMilestone()
        XCTAssertEqual(state.missions.first?.progress, 800)
        state.distance = 850
        state.noteDistanceMilestone()
        XCTAssertEqual(state.missions.first?.progress, 850)
    }

    func testCollectiblesKeepTheirPlacedHeightIncludingZero() {
        for height: Float in [0, 0.6, 2.8, 6] {
            let token = Collectible(kind: .token)
            token.node.position.y = height
            for _ in 0..<120 {
                token.update(dt: 1.0 / 60)
                XCTAssertEqual(token.node.position.y, height, accuracy: 0.081)
            }
        }
    }

    func testRoofJumpRisesAndReturnsToRoofWhileJetpackUsesFlightHeight() {
        let player = Player()
        player.prepareForRun()
        player.onTrainTop = true
        player.trainTopY = 2.8
        player.update(dt: 0, speed: 12, flying: false, groundY: 0)
        XCTAssertTrue(player.jump())
        player.update(dt: 0.3, speed: 12, flying: false, groundY: 0)
        XCTAssertGreaterThan(player.node.position.y, 3.8)
        player.update(dt: 2, speed: 12, flying: false, groundY: 0)
        XCTAssertEqual(player.node.position.y, 2.8, accuracy: 0.001)
        player.update(dt: 0.1, speed: 12, flying: true, groundY: 0)
        XCTAssertEqual(player.node.position.y, 6, accuracy: 0.001)
    }

    func testFlatbedApproachClimbsFromNearEndToDeck() throws {
        let flatbed = Obstacle(kind: .flatbed, length: 16)
        flatbed.node.position.z = -8
        XCTAssertEqual(flatbed.surfaceHeight(at: 0), 0, accuracy: 0.001)
        flatbed.node.position.z = -7.5
        XCTAssertEqual(flatbed.surfaceHeight(at: 0), 0.175, accuracy: 0.001)
        flatbed.node.position.z = -6
        XCTAssertEqual(flatbed.surfaceHeight(at: 0), 0.7, accuracy: 0.001)
        flatbed.node.position.z = -4
        XCTAssertEqual(flatbed.surfaceHeight(at: 0), 1.4, accuracy: 0.001)
        flatbed.node.position.z = 0
        XCTAssertEqual(flatbed.surfaceHeight(at: 0), 1.4, accuracy: 0.001)

        let ramp = try XCTUnwrap(flatbed.node.childNodes.first { $0.rotation.x == 1 && $0.rotation.w > 0 })
        let geometry = try XCTUnwrap(ramp.geometry as? SCNBox)
        let near = ramp.convertPosition(SCNVector3(0, 0, Float(geometry.length) / 2), to: flatbed.node)
        let far = ramp.convertPosition(SCNVector3(0, 0, -Float(geometry.length) / 2), to: flatbed.node)
        XCTAssertEqual(near.z, 8, accuracy: 0.001)
        XCTAssertEqual(near.y, 0, accuracy: 0.001)
        XCTAssertEqual(far.z, 4, accuracy: 0.001)
        XCTAssertEqual(far.y, 1.4, accuracy: 0.001)
    }
}
