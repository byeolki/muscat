import PodoKit
import SwiftUI

struct AdminStorageView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    @State private var stats: StorageStats?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    var body: some View {
        List {
            if let stats {
                Section("디스크") {
                    LabeledContent("전체", value: byteFormatter.string(fromByteCount: Int64(stats.disk.totalBytes)))
                    LabeledContent("사용 중", value: byteFormatter.string(fromByteCount: Int64(stats.disk.usedBytes)))
                    LabeledContent("여유 공간", value: byteFormatter.string(fromByteCount: Int64(stats.disk.freeBytes)))
                }
                Section("디렉터리") {
                    LabeledContent("업로드", value: byteFormatter.string(fromByteCount: Int64(stats.uploadDir.sizeBytes)))
                    LabeledContent("아트워크", value: byteFormatter.string(fromByteCount: Int64(stats.artworkDir.sizeBytes)))
                    LabeledContent("트랜스코드 캐시", value: byteFormatter.string(fromByteCount: Int64(stats.transcodeCache.sizeBytes)))
                }
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
        .navigationTitle("저장소 사용량")
        .overlay {
            if isLoading && stats == nil {
                ProgressView()
            }
        }
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            stats = try await appEnvironment.apiClient.fetchStorageStats()
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }
}
