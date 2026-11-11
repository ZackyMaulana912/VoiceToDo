import SwiftUI

struct RecordingView: View {
    @ObservedObject var recorder: SpeechRecorder
    let onCancel: () -> Void
    let onFinish: (RecordedAudio) -> Void

    @State private var isFinishing = false

    // Light/dark pattern copied from the Figma waveform.
    private let lightBars: Set<Int> = [0, 3, 6, 9, 12, 15, 18]

    var body: some View {
        VStack(spacing: 0) {
            Text("Rekaman baru")
                .font(.inter(18, weight: .semibold))
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 24)

            Spacer(minLength: 0)

            if let message = recorder.errorMessage {
                errorView(message)
            } else {
                recordingBody
            }

            Spacer(minLength: 0)

            VStack(spacing: 56) {
                Text("Jaga layar tetap menyala saat merekam")
                    .font(.inter(13, weight: .medium))
                    .foregroundStyle(Color.mutedInk)
                buttons
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .task { startIfNeeded() }
        .onChange(of: recorder.elapsed) { value in
            if value >= SpeechRecorder.maxSeconds { finish() }
        }
    }

    private var recordingBody: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.recordingRed)
                    .frame(width: 12, height: 12)
                Text("Merekam")
                    .font(.inter(16, weight: .medium))
                    .foregroundStyle(Color(hex: 0xB91C1C))
            }

            Text(Formatters.duration(recorder.elapsed))
                .font(.inter(48, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.ink)

            waveform
                .padding(.top, 24)

            Text("Maks 10 menit")
                .font(.inter(13, weight: .medium))
                .foregroundStyle(Color.mutedInk)
                .padding(.top, 8)
        }
    }

    private var waveform: some View {
        HStack(spacing: 8) {
            ForEach(Array(recorder.levels.enumerated()), id: \.offset) { index, level in
                RoundedRectangle(cornerRadius: 3)
                    .fill(lightBars.contains(index) ? Color(hex: 0xF4A3A6) : Color.recordingRed)
                    .frame(width: 6, height: 8 + level * 88)
            }
        }
        .frame(height: 96)
        .animation(.easeOut(duration: 0.12), value: recorder.levels)
        .accessibilityHidden(true)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image("warn").frame(width: 24, height: 24)
            Text(message)
                .font(.inter(16))
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button {
                recorder.cancel()
                onCancel()
            } label: {
                Text(recorder.errorMessage == nil ? "Batal" : "Tutup")
                    .font(.inter(16, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .frame(width: 108, height: 56)
                    .background(Color.white)
                    .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.border, lineWidth: 1) }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            if recorder.errorMessage == nil {
                Button(action: finish) {
                    HStack(spacing: 10) {
                        Image("stop").frame(width: 20, height: 20)
                        Text("Selesai").font(.inter(16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(hex: 0xDC2626))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func startIfNeeded() {
        do {
            try recorder.start()
        } catch {
            recorder.errorMessage = error.localizedDescription
        }
    }

    private func finish() {
        guard !isFinishing, recorder.errorMessage == nil else { return }
        isFinishing = true
        Task {
            let audio = await recorder.stop()
            onFinish(audio)
        }
    }
}
