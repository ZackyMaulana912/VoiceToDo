import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    let onRecord: () -> Void

    private enum Filter: String, CaseIterable {
        case pending = "Belum"
        case completed = "Selesai"
    }

    @State private var filter: Filter = .pending
    @State private var pendingDelete: TodoItem?
    @State private var editing: TodoItem?
    @State private var adding = false

    private var visibleTodos: [TodoItem] {
        // To-do yang sudah tampil di kartu hasil tidak diulang di daftar bawahnya. Setelah kartu hasil
        // ditutup (pindah tab atau segmen), to-do itu kembali muncul di daftar seperti biasa.
        let inResultCard: Set<UUID> = store.banner?.kind == .result ? Set(bannerRecording?.todoIDs ?? []) : []
        return store.todos.filter {
            (filter == .completed ? $0.isDone : !$0.isDone) && !inResultCard.contains($0.id)
        }
    }

    private var bannerRecording: Recording? {
        guard filter == .pending, let banner = store.banner else { return nil }
        return store.recording(banner.recordingID)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(spacing: 12) {
                    banner
                    ForEach(visibleTodos) { item in
                        TodoCardView(item: item) { withAnimation(.easeInOut(duration: 0.2)) { store.toggle(item.id) } }
                            .todoMenu(onEdit: { editing = item }, onDelete: { pendingDelete = item })
                    }
                    if visibleTodos.isEmpty && bannerRecording == nil {
                        EmptyStateView(
                            title: filter == .pending ? "Belum ada to-do" : "Belum ada to-do selesai",
                            message: filter == .pending
                                ? "Rekam sesuatu, nanti kurangkum jadi daftar tugas."
                                : "Centang to-do yang sudah beres, nanti muncul di sini."
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .confirmTodoDelete($pendingDelete) { id in
                withAnimation(.easeInOut(duration: 0.2)) { store.deleteTodo(id) }
            }
            .todoEditSheet($editing) { store.editTodo($0, title: $1) }
            .todoAddSheet(isPresented: $adding) { text, category in
                filter = .pending // to-do baru selalu "Belum", jadi tampilkan segmen itu
                withAnimation(.easeInOut(duration: 0.2)) { store.addTodo(title: text, category: category) }
            }

            RecordAreaView(onRecord: onRecord)
        }
    }

    @ViewBuilder
    private var banner: some View {
        if let recording = bannerRecording, let banner = store.banner {
            switch banner.kind {
            case .processing:
                ProcessingCardView(duration: recording.durationText, stage: store.activeID == recording.id ? store.stage?.text : nil)
            case .failed:
                FailedCardView(
                    message: recording.failMessage,
                    onRetry: recording.canRetry ? { store.retry(recording.id) } : nil
                )
            case .result:
                ResultCardView(
                    recording: recording,
                    todos: store.todos(for: recording),
                    onToggle: store.toggle,
                    onSummaryChange: { store.updateSummary(recording.id, text: $0) },
                    onEditTodo: { editing = $0 },
                    onDeleteTodo: { pendingDelete = $0 }
                )
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Voice-to-Todo")
                .font(.inter(24, weight: .semibold))
                .foregroundStyle(Color.ink)
                .frame(height: 32, alignment: .leading)
                .padding(.top, 24)

            HStack {
                Text("To-do kamu")
                    .font(.inter(18, weight: .semibold))
                    .foregroundStyle(Color.ink)
                Spacer()
                Button { adding = true } label: {
                    Text("+ Tambah")
                        .font(.inter(16, weight: .semibold))
                        .foregroundStyle(Color.brand)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tambah to-do")
            }
            .frame(height: 28)
            .padding(.top, 40)

            HStack(spacing: 0) {
                ForEach(Filter.allCases, id: \.self) { option in
                    Button {
                        filter = option
                        store.dismissResultBanner()
                    } label: {
                        Text(option.rawValue)
                            .font(.inter(13, weight: .medium))
                            .foregroundStyle(filter == option ? Color.brand : Color.mutedInk)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(RoundedRectangle(cornerRadius: 8).fill(filter == option ? Color.white : Color.clear))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(filter == option ? .isSelected : [])
                }
            }
            .padding(4)
            .frame(height: 48)
            .background(Color(hex: 0xEEF2F6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
    }
}
