import AVFoundation
import CoreGraphics

/// Format rekaman (CLAUDE.md `FORMAT_AUDIO`): WAV PCM 16 kHz mono 16-bit, format yang dipakai Whisper.
/// Rekaman 10 menit sekitar 19 MB.
enum RecordingFormat {
    static let sampleRate: Double = 16_000
    static let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: 1, interleaved: true)!
}

/// Bagian yang disentuh dari thread audio realtime. Dipisah dari perekam yang berjalan di main actor.
final class AudioSink: @unchecked Sendable {
    private let lock = NSLock()
    private var file: AVAudioFile?
    private var converter: AVAudioConverter?
    private var frames: AVAudioFramePosition = 0
    var onLevel: (@Sendable (CGFloat) -> Void)?

    func begin(file: AVAudioFile, converter: AVAudioConverter) {
        lock.lock(); defer { lock.unlock() }
        self.file = file
        self.converter = converter
        frames = 0
    }

    /// Menutup file dan mengembalikan jumlah sampel 16 kHz yang tertulis.
    func end() -> AVAudioFramePosition {
        lock.lock(); defer { lock.unlock() }
        file = nil // AVAudioFile menulis ukuran akhir ke header WAV saat dilepas
        converter = nil
        onLevel = nil
        return frames
    }

    func write(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard let file, let converter, buffer.frameLength > 0 else { return }

        // Ubah dari format mikrofon (biasanya 48 kHz float) ke 16 kHz mono 16-bit.
        let ratio = RecordingFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: RecordingFormat.format, frameCapacity: capacity) else { return }
        var given = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if given {
                status.pointee = .noDataNow // tunggu buffer berikutnya, jangan akhiri aliran
                return nil
            }
            given = true
            status.pointee = .haveData
            return buffer
        }
        if error == nil, out.frameLength > 0 {
            do {
                try file.write(from: out)
                frames += AVAudioFramePosition(out.frameLength)
            } catch {}
        }

        if let channel = buffer.floatChannelData?[0] {
            let count = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<count { sum += channel[i] * channel[i] }
            let rms = sqrt(sum / Float(count))
            onLevel?(CGFloat(min(1, rms * 9)))
        }
    }
}
