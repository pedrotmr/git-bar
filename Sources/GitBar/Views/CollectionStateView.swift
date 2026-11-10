import SwiftUI

struct CollectionStateView<Rows: View>: View {
    let isLoading: Bool
    let isEmpty: Bool
    let emptySymbol: String
    let emptyMessage: String
    let rows: Rows

    init(
        isLoading: Bool,
        isEmpty: Bool,
        emptySymbol: String,
        emptyMessage: String,
        @ViewBuilder rows: () -> Rows
    ) {
        self.isLoading = isLoading
        self.isEmpty = isEmpty
        self.emptySymbol = emptySymbol
        self.emptyMessage = emptyMessage
        self.rows = rows()
    }

    var body: some View {
        Group {
            if isLoading {
                loadingState
            } else if isEmpty {
                emptyState
            } else {
                ScrollView {
                    rows
                }
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingState: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading…")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: emptySymbol)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.secondary)
            Text(emptyMessage)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
