import AVFoundation

final class SoundService: @unchecked Sendable {
    static let shared = SoundService()

    private let queue = DispatchQueue(label: "com.myplayground.SoundService", qos: .userInteractive)
    private var players: [String: AVAudioPlayer] = [:]

    private init() {
        setupAudioSession()
        generateSyntheticSounds()
    }

    private func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Synthetic sound generation via AVAudioEngine

    private func generateSyntheticSounds() {
        let select = makeTonePlayer(frequency: 660, duration: 0.08, amplitude: 0.3)
        let match = makeTonePlayer(frequency: 880, duration: 0.25, amplitude: 0.5)
        let invalid = makeTonePlayer(frequency: 220, duration: 0.15, amplitude: 0.4)
        let victory = makeTonePlayer(frequency: 1046, duration: 0.5, amplitude: 0.6)
        let deadlock = makeTonePlayer(frequency: 330, duration: 0.3, amplitude: 0.3)
        let lock = makeTonePlayer(frequency: 180, duration: 0.12, amplitude: 0.35)

        queue.sync {
            self.players["tile_select"] = select
            self.players["tile_match"] = match
            self.players["tile_invalid"] = invalid
            self.players["victory"] = victory
            self.players["deadlock"] = deadlock
            self.players["lock"] = lock
        }
    }

    private func makeTonePlayer(frequency: Float, duration: Double, amplitude: Float) -> AVAudioPlayer? {
        let sampleRate: Double = 44100
        let frameCount = Int(sampleRate * duration)
        var samples = [Int16](repeating: 0, count: frameCount)

        for i in 0..<frameCount {
            let t: Double = Double(i) / sampleRate
            let attack: Double = t / 0.01
            let release: Double = (duration - t) / 0.05
            let envelope: Double = min(1.0, min(attack, release))
            let wave: Double = sin(2.0 * Double.pi * Double(frequency) * t)
            let sample: Float = Float(amplitude) * Float(envelope) * Float(wave)
            let clamped: Int = max(-32767, min(32767, Int(sample * 32767)))
            samples[i] = Int16(clamped)
        }

        // Build WAV data
        var data = Data()
        func write<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }

        let dataSize = frameCount * 2
        let fileSize = dataSize + 36

        data.append(contentsOf: "RIFF".utf8)
        write(UInt32(fileSize))
        data.append(contentsOf: "WAVEfmt ".utf8)
        write(UInt32(16))      // chunk size
        write(UInt16(1))       // PCM
        write(UInt16(1))       // mono
        write(UInt32(sampleRate))
        write(UInt32(UInt32(sampleRate) * 2))
        write(UInt16(2))       // block align
        write(UInt16(16))      // bits per sample
        data.append(contentsOf: "data".utf8)
        write(UInt32(dataSize))
        for s in samples { write(s) }

        return try? AVAudioPlayer(data: data)
    }

    // MARK: - Playback

    func play(_ sound: String) {
        guard PersistenceService.shared.soundEnabled else { return }
        
        let playBlock = { [weak self] in
            guard let self else { return }
            let player = self.queue.sync { self.players[sound] }
            player?.currentTime = 0
            player?.play()
        }

        if Thread.isMainThread {
            playBlock()
        } else {
            DispatchQueue.main.async(execute: playBlock)
        }
    }
}
