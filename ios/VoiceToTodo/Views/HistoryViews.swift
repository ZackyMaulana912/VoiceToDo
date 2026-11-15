import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    let onOpen: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Voice-to-Todo")
                .font(.inter(24, weight: .semibold))
                .foregroundStyle(Color.ink)
                .frame(minHeight: 32, alignment: .leading)
                .padding(.top, 24)

            Text("Riwayat")
                .font(.inter(24, weight: .semibold))
                .foregroundStyle(Color.ink)
                .frame(minHeight: 32, alignment: .leading)
                .padding(.top, 40)

            Text("Rekamanmu, sudah dirapikan.")
                .font(.inter(16))
                .foregroundStyle(Color.mutedInk)
                .frame(minHeight: 24, alignment: .leading)
                .padding(.bottom, 24)

            if store.recordings.isEmpty {
                EmptyStateView(
                    title: "Belum ada riwayat",
                    message: "Rekamanmu akan muncul di sini setelah kamu merekam."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(store.recordings) { recording in
                            Button { onOpen(recording.id) } label: { row(recording) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func row(_ recording: Recording) -> some View {
        let subtitle: String
        switch recording.status {
        case .processing: subtitle = store.activeID == recording.id ? (store.stage?.text ?? "Memproses...") : "Menunggu giliran..."
        case .failed: subtitle = recording.failMessage
        case .done: subtitle = recording.summary.components(separatedBy: ". ").first ?? recording.summary
        }
        return VStack(alignment: .leading, spacing: 0) {
            Text(recording.dateText)
                .font(.inter(13, weight: .medium))
                .foregroundStyle(Color.mutedInk)
            Text(recording.title)
                .font(.inter(16, weight: .semibold))
                .foregroundStyle(Color.ink)
                .padding(.top, 6)
            Text(subtitle)
                .font(.inter(13, weight: .medium))
                .foregroundStyle(Color.mutedInk)
                .lineLimit(1)
                .padding(.top, 4)
            HStack(spacing: 8) {
                CategoryChip(category: recording.category)
                StatusChip(status: recording.status)
                Spacer(minLength: 8)
                Text(recording.status == .done ? "\(recording.todoIDs.count) to-do · \(recording.durationText)" : recording.durationText)
                    .font(.inter(13, weight: .medium))
                    .foregroundStyle(Color.mutedInk)
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 15)
        .padding(.top, 11)
        .padding(.bottom, 7)
        .cardStyle()
    }
}

struct DetailView: View {
    @EnvironmentObject private var store: AppStore
    let recordingID: UUID
    let onBack: () -> Void
    let onRetry: () -> Void

    @State private var showTranscript = false
    @State private var pendingTodoDelete: TodoItem?
    @State private var editingTodo: TodoItem?
    @State private var confirmDeleteRecording = false
    @State private var editingTranscript = false
    @State private var showOriginalTranscript = false
    @State private var confirmResummary = false

    var body: some View {
        if let recording = store.recording(recordingID) {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: onBack) {
                    Text("‹  Riwayat")
                        .font(.inter(16, weight: .medium))
                        .foregroundStyle(Color.brand)
                        .frame(minHeight: 48, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.top, 12)

                Text(recording.title)
                    .font(.inter(24, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .padding(.top, 20)
                Text("\(recording.dateText) · \(recording.durationText)")
                    .font(.inter(13, weight: .medium))
                    .foregroundStyle(Color.mutedInk)
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 16) {
                        if let note = recording.stopNote {
                            Text(note)
                                .font(.inter(13, weight: .medium))
                                .foregroundStyle(Color(hex: 0x92400E))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        switch recording.status {
                        case .done:
                            ResultCardView(
                                recording: recording,
                                todos: store.todos(for: recording),
                                onToggle: store.toggle,
                                onSummaryChange: { store.updateSummary(recording.id, text: $0) },
                                onEditTodo: { editingTodo = $0 },
                                onDeleteTodo: { pendingTodoDelete = $0 }
                            )
                            transcript(recording)
                        case .processing:
                            ProcessingCardView(duration: recording.durationText, stage: store.activeID == recording.id ? store.stage?.text : nil)
                        case .failed:
                            FailedCardView(message: recording.failMessage, onRetry: recording.canRetry ? onRetry : nil)
                            // Transkrip yang sempat jadi (misalnya ringkasan gagal) bisa dibetulkan sebelum Coba lagi.
                            if !recording.transcript.isEmpty { transcript(recording) }
                        }
                        if recording.status != .processing {
                            deleteRecordingButton(recording)
                        }
                    }
                    .padding(.bottom, 16)
                }
                .confirmTodoDelete($pendingTodoDelete) { store.deleteTodo($0) }
                .todoEditSheet($editingTodo) { store.editTodo($0, title: $1) }
                .sheet(isPresented: $editingTranscript) {
                    TranscriptEditView(initialText: recording.transcript) { store.editTranscript(recording.id, text: $0) }
                }
                .sheet(isPresented: $showOriginalTranscript) {
                    OriginalTranscriptView(text: recording.originalTranscript ?? recording.transcript) {
                        store.editTranscript(recording.id, text: $0)
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity, alignment: .top)
        } else {
            Color.clear.onAppear(perform: onBack)
        }
    }

    private func deleteRecordingButton(_ recording: Recording) -> some View {
        let todoCount = store.todos(for: recording).count
        return Button { confirmDeleteRecording = true } label: {
            Text("Hapus rekaman")
                .font(.inter(16, weight: .semibold))
                .foregroundStyle(Color(hex: 0xDC2626))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background(Color.white)
                .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.border, lineWidth: 1) }
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
        .confirmationDialog("Hapus rekaman ini?", isPresented: $confirmDeleteRecording, titleVisibility: .visible) {
            Button("Hapus rekaman", role: .destructive) {
                store.deleteRecording(recording.id)
                onBack()
            }
            Button("Batal", role: .cancel) {}
        } message: {
            Text(todoCount == 0
                 ? "Audio dan isi rekaman ini akan dihapus. Kamu masih bisa mengurungkannya beberapa detik setelahnya."
                 : "Audio, isi rekaman, dan \(todoCount) to-do dari rekaman ini akan dihapus. Kamu masih bisa mengurungkannya beberapa detik setelahnya.")
        }
    }

    private func transcript(_ recording: Recording) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { showTranscript.toggle() } } label: {
                HStack(spacing: 8) {
                    Text("Transkrip lengkap")
                        .font(.inter(16, weight: .medium))
                        .foregroundStyle(Color.ink)
                    if recording.isTranscriptEdited {
                        ChipView(title: "Diedit", foreground: Color(hex: 0x475569), background: Color(hex: 0xF1F5F9))
                    }
                    Spacer()
                    Text("⌄")
                        .font(.inter(16, weight: .medium))
                        .foregroundStyle(Color.mutedInk)
                        .rotationEffect(.degrees(showTranscript ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 15)
                .frame(minHeight: 56)
            }
            .buttonStyle(.plain)
            .accessibilityValue(showTranscript ? "terbuka" : "tertutup")

            // Tetap tampil walau transkrip ditutup, supaya tidak terlewat.
            if recording.needsResummary {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Transkrip sudah diubah. Ringkasan dan to-do di atas masih dari transkrip sebelumnya.")
                        .font(.inter(13, weight: .medium))
                        .foregroundStyle(Color(hex: 0x92400E))
                        .fixedSize(horizontal: false, vertical: true)
                    Button { confirmResummary = true } label: {
                        Text("Ringkas ulang")
                            .font(.inter(16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 48)
                            .background(Color.brand)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 16)
            }

            if showTranscript {
                Text(recording.transcript)
                    .font(.inter(16))
                    .foregroundStyle(Color.ink)
                    .lineSpacing(5)
                    .textSelection(.enabled)
                    .padding(.horizontal, 15)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    transcriptButton("Edit transkrip", icon: "edit") { editingTranscript = true }
                    if recording.isTranscriptEdited {
                        transcriptButton("Lihat transkrip asli", icon: nil) { showOriginalTranscript = true }
                    }
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 16)
            }
        }
        .cardStyle()
        .confirmationDialog("Ringkas ulang dari transkrip ini?", isPresented: $confirmResummary, titleVisibility: .visible) {
            Button("Ringkas ulang") { store.resummarize(recording.id) }
            Button("Batal", role: .cancel) {}
        } message: {
            let count = store.todos(for: recording).count
            Text("Ringkasan, poin penting, dan \(count) to-do dari rekaman ini akan diganti dengan hasil baru. "
                 + "Centang dan perubahan di to-do lama ikut hilang.")
        }
    }

    private func transcriptButton(_ title: String, icon: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(icon).frame(width: 20, height: 20).accessibilityHidden(true) }
                Text(title).font(.inter(13, weight: .medium)).multilineTextAlignment(.center)
            }
            .foregroundStyle(Color.brand)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.border, lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }
}
