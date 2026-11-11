import SwiftUI

struct RecordingView: View {
    @ObservedObject var recorder: SpeechRecorder
    let onCancel: () -> Void
    let onFinish: (RecordedAudio) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var isFinishing = false
    @State private var confirmCancel = false

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
                if isFinishing {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Menyimpan rekaman…")
                    }
                    .font(.inter(13, weight: .medium))
                    .foregroundStyle(Color.mutedInk)
                } else {
                    Text("Jaga layar tetap menyala saat merekam")
                        .font(.inter(13, weight: .medium))
                        .foregroundStyle(Color.mutedInk)
                }
                buttons
                    .disabled(isFinishing)
                    .opacity(isFinishing ? 0.5 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .task { startIfNeeded() }
        .onChange(of: recorder.elapsed) { value in
            if value >= SpeechRecorder.maxSeconds { finish() }
        }
        .onChange(of: recorder.interruption) { reason in
            if let reason { finish(note: reason) }
        }
        .onChange(of: scenePhase) { phase in
            // Tanpa izin rekam di latar belakang, iOS memutus mikrofon saat layar dikunci atau aplikasi
            // ditinggalkan. Simpan bagian yang sudah terekam (REKAMAN_TERPUTUS) supaya tidak hilang.
            if phase == .background {
                finish(note: "Rekaman berhenti karena layar dikunci atau aplikasi ditinggalkan.")
            }
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
                if recorder.errorMessage == nil {
                    confirmCancel = true // rekaman sedang berjalan: tanya dulu sebelum dibuang
                } else {
                    discard()
                }
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
            .confirmationDialog("Buang rekaman ini?", isPresented: $confirmCancel, titleVisibility: .visible) {
                Button("Buang rekaman", role: .destructive, action: discard)
                Button("Lanjut merekam", role: .cancel) {}
            } message: {
                Text("Rekaman \(Formatters.duration(recorder.elapsed)) akan dihapus dan tidak bisa dikembalikan.")
            }

            if recorder.errorMessage == nil {
                Button { finish() } label: {
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

    private func discard() {
        guard !isFinishing else { return } // rekaman sedang disimpan: jangan dibuang di tengah jalan
        recorder.cancel()
        onCancel()
    }

    private func finish(note: String? = nil) {
        guard !isFinishing, recorder.errorMessage == nil else { return }
        isFinishing = true
        // Minta waktu tambahan ke iOS supaya penyimpanan tetap selesai walau aplikasi sedang ditinggalkan.
        let app = UIApplication.shared
        let backgroundTask = app.beginBackgroundTask(withName: "simpan-rekaman")
        Task {
            let audio = await recorder.stop(note: note)
            onFinish(audio)
            if backgroundTask != .invalid { app.endBackgroundTask(backgroundTask) }
        }
    }
}
