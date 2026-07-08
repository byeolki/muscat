import MuscatKit
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
                Section("Disk") {
                    LabeledContent("Total", value: byteFormatter.string(fromByteCount: Int64(stats.disk.totalBytes)))
                    LabeledContent("Used", value: byteFormatter.string(fromByteCount: Int64(stats.disk.usedBytes)))
                    LabeledContent("Free", value: byteFormatter.string(fromByteCount: Int64(stats.disk.freeBytes)))
                }
                Section("Directories") {
                    LabeledContent("Uploads", value: byteFormatter.string(fromByteCount: Int64(stats.uploadDir.sizeBytes)))
                    LabeledContent("Artwork", value: byteFormatter.string(fromByteCount: Int64(stats.artworkDir.sizeBytes)))
                    LabeledContent("Transcode Cache", value: byteFormatter.string(fromByteCount: Int64(stats.transcodeCache.sizeBytes)))
                }
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
        .navigationTitle("Storage Usage")
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
