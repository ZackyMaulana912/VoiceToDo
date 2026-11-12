import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    let onOpen: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Voice-to-Todo")
                .font(.inter(24, weight: .semibold))
                .foregroundStyle(Color.ink)
                .frame(height: 32, alignment: .leading)
                .padding(.top, 24)

            Text("Riwayat")
                .font(.inter(24, weight: .semibold))
                .foregroundStyle(Color.ink)
                .frame(height: 32, alignment: .leading)
                .padding(.top, 40)

            Text("Rekamanmu, sudah dirapikan.")
                .font(.inter(16))
                .foregroundStyle(Color.mutedInk)
                .frame(height: 24, alignment: .leading)
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
        case .processing: subtitle = "Merangkum rekaman \(recording.durationText)..."
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

    var body: some View {
        if let recording = store.recording(recordingID) {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: onBack) {
                    Text("‹  Riwayat")
                        .font(.inter(16, weight: .medium))
                        .foregroundStyle(Color.brand)
                        .frame(height: 48, alignment: .leading)
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
                            ProcessingCardView(duration: recording.durationText)
                        case .failed:
                            FailedCardView(message: recording.failMessage, onRetry: recording.canRetry ? onRetry : nil)
                        }
                        if recording.status != .processing {
                            deleteRecordingButton(recording)
                        }
                    }
                    .padding(.bottom, 16)
                }
                .confirmTodoDelete($pendingTodoDelete) { store.deleteTodo($0) }
                .todoEditSheet($editingTodo) { store.editTodo($0, title: $1) }
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
                .frame(height: 48)
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
                 ? "Audio dan isi rekaman ini akan dihapus dan tidak bisa dikembalikan."
                 : "Audio, isi rekaman, dan \(todoCount) to-do dari rekaman ini akan dihapus dan tidak bisa dikembalikan.")
        }
    }

    private func transcript(_ recording: Recording) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { showTranscript.toggle() } } label: {
                HStack {
                    Text("Transkrip lengkap")
                        .font(.inter(16, weight: .medium))
                        .foregroundStyle(Color.ink)
                    Spacer()
                    Text("⌄")
                        .font(.inter(16, weight: .medium))
                        .foregroundStyle(Color.mutedInk)
                        .rotationEffect(.degrees(showTranscript ? 180 : 0))
                }
                .padding(.horizontal, 15)
                .frame(height: 56)
            }
            .buttonStyle(.plain)

            if showTranscript {
                Text(recording.transcript)
                    .font(.inter(16))
                    .foregroundStyle(Color.ink)
                    .lineSpacing(5)
                    .padding(.horizontal, 15)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .cardStyle()
    }
}
