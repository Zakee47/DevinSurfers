import Foundation
import AVFoundation
import UIKit

/// Lightweight synthesized SFX via AVAudioEngine + haptics.
/// Never crashes if the audio session is unavailable (e.g. simulator).
final class GameAudio {
    static let shared = GameAudio()

    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var ok = false

    private init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient)
            try AVAudioSession.sharedInstance().setActive(true)
            let e = AVAudioEngine()
            let p = AVAudioPlayerNode()
            e.attach(p)
            e.connect(p, to: e.mainMixerNode, format: nil)
            try e.start()
            p.play()
            engine = e
            player = p
            ok = true
        } catch {
            ok = false
        }
    }

    private func blip(freq: Double, duration: Double, type: String = "sine", volume: Float = 0.25) {
        guard ok, let engine, let player else { return }
        let sr = 44100.0
        let frames = AVAudioFrameCount(sr * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
        buffer.frameLength = frames
        let data = buffer.floatChannelData![0]
        for i in 0..<Int(frames) {
            let t = Double(i) / sr
            let env = Float(max(0, 1 - t / duration))
            let s = type == "square"
                ? (sin(2 * .pi * freq * t) > 0 ? 1.0 : -1.0)
                : sin(2 * .pi * freq * t)
            data[i] = Float(s) * env * volume
        }
        if !engine.isRunning { try? engine.start(); player.play() }
        player.scheduleBuffer(buffer, completionHandler: nil)
    }

    func coin() { blip(freq: 1320, duration: 0.08); blip(freq: 1760, duration: 0.12) }
    func jump() { blip(freq: 500, duration: 0.15) }
    func powerUp() { blip(freq: 660, duration: 0.1); blip(freq: 880, duration: 0.1); blip(freq: 1100, duration: 0.2) }
    func crash() { blip(freq: 140, duration: 0.4, type: "square", volume: 0.4) }
    func stumble() { blip(freq: 220, duration: 0.2, type: "square", volume: 0.3) }
    func swipe() { blip(freq: 900, duration: 0.05, volume: 0.1) }

    func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        DispatchQueue.main.async {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }
}
