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

    private var diskUsedFraction: Double {
        guard let stats, stats.disk.totalBytes > 0 else { return 0 }
        return Double(stats.disk.usedBytes) / Double(stats.disk.totalBytes)
    }

    var body: some View {
        List {
            if let stats {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Disk")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.appTextPrimary)
                            Spacer()
                            Text("\(Int((diskUsedFraction * 100).rounded()))% used")
                                .font(.caption)
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.appBorder)
                                Capsule()
                                    .fill(Color.appAccent)
                                    .frame(width: geometry.size.width * diskUsedFraction)
                            }
                        }
                        .frame(height: 6)
                        HStack {
                            statLabel("Used", bytes: stats.disk.usedBytes)
                            Spacer()
                            statLabel("Free", bytes: stats.disk.freeBytes)
                            Spacer()
                            statLabel("Total", bytes: stats.disk.totalBytes)
                        }
                    }
                    .padding(16)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                Section {
                    directoryRow(name: "Uploads", bytes: stats.uploadDir.sizeBytes)
                    directoryRow(name: "Artwork", bytes: stats.artworkDir.sizeBytes)
                    directoryRow(name: "Transcode Cache", bytes: stats.transcodeCache.sizeBytes)
                } header: {
                    Text("DIRECTORIES")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appTextTertiary)
                        .kerning(0.8)
                }
            }
            if let errorMessage {
                ErrorBanner(message: errorMessage)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .themedList()
        .navigationTitle("Storage Usage")
        .overlay {
            if isLoading && stats == nil {
                ProgressView().tint(Color.appAccent)
            }
        }
        .refreshable { await load() }
        .task { await load() }
    }

    private func statLabel(_ title: String, bytes: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Color.appTextTertiary)
            Text(byteFormatter.string(fromByteCount: Int64(bytes)))
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.appTextPrimary)
                .monospacedDigit()
        }
    }

    private func directoryRow(name: String, bytes: Int) -> some View {
        HStack {
            Text(name)
                .font(.subheadline)
                .foregroundStyle(Color.appTextPrimary)
            Spacer()
            Text(byteFormatter.string(fromByteCount: Int64(bytes)))
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
                .monospacedDigit()
        }
        .themedRow()
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
