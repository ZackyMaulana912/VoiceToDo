import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    let onRecord: () -> Void

    private enum Filter: String, CaseIterable {
        case pending = "Belum"
        case completed = "Selesai"
    }

    @State private var filter: Filter = .pending

    private var visibleTodos: [TodoItem] {
        store.todos.filter { filter == .completed ? $0.isDone : !$0.isDone }
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

            RecordAreaView(onRecord: onRecord)
        }
    }

    @ViewBuilder
    private var banner: some View {
        if let recording = bannerRecording, let banner = store.banner {
            switch banner.kind {
            case .processing:
                ProcessingCardView(duration: recording.durationText)
            case .failed:
                FailedCardView { store.retry(recording.id) }
            case .result:
                ResultCardView(
                    recording: recording,
                    todos: store.todos(for: recording),
                    onToggle: store.toggle,
                    onSummaryChange: { store.updateSummary(recording.id, text: $0) }
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

            Text("To-do kamu")
                .font(.inter(18, weight: .semibold))
                .foregroundStyle(Color.ink)
                .frame(height: 28, alignment: .leading)
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
