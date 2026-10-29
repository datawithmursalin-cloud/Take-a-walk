import Foundation

/// A two-second, softly attacked double bell, generated locally as mono PCM WAV.
/// No downloaded assets or system alert-sound settings are needed.
public enum ReminderTone {
    public static func wavData() -> Data {
        let rate = 22_050
        let frames = rate * 2
        let byteCount = UInt32(frames * 2)
        var data = Data()
        func word(_ value: UInt16) {
            var value = value.littleEndian
            withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
        }
        func dword(_ value: UInt32) {
            var value = value.littleEndian
            withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: "RIFF".utf8)
        dword(36 + byteCount)
        data.append(contentsOf: "WAVEfmt ".utf8)
        dword(16)
        word(1) // PCM
        word(1) // Mono
        dword(UInt32(rate))
        dword(UInt32(rate * 2))
        word(2)
        word(16)
        data.append(contentsOf: "data".utf8)
        dword(byteCount)
        for frame in 0..<frames {
            let time = Double(frame) / Double(rate)
            var sample = 0.0
            for onset in [0.0, 0.35] {
                let t = time - onset
                if t >= 0, t < 1 {
                    let attack = min(1, t / 0.008)
                    let release = min(1, (1 - t) / 0.025)
                    let bell = sin(2 * .pi * 880 * t) + 0.22 * sin(2 * .pi * 1760 * t)
                    sample += 0.42 * attack * release * exp(-6 * t) * bell
                }
            }
            let pcm = Int16(max(-1, min(1, sample)) * Double(Int16.max))
            word(UInt16(bitPattern: pcm))
        }
        return data
    }
}
