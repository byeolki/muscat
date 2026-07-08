import MuscatKit
import SwiftUI
import UniformTypeIdentifiers

struct MyFilesView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    @State private var files: [UploadedFileEntry] = []
    @State private var isLoading = false
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var showFileImporter = false
    @State private var renamingFile: UploadedFileEntry?
    @State private var renameText = ""

    var body: some View {
        List {
            if isUploading {
                HStack(spacing: 10) {
                    ProgressView().tint(Color.appAccent)
                    Text("Uploading...")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextSecondary)
                }
                .themedRow()
            }
            ForEach(files) { file in
                HStack(spacing: 12) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.appTextTertiary)
                        .frame(width: 36, height: 36)
                        .background(Color.appSurfaceRaised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(file.trackTitle)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.appTextPrimary)
                        Text(file.filename)
                            .font(.caption)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
                .padding(.vertical, 2)
                .themedRow()
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await delete(file) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        renamingFile = file
                        renameText = file.filename
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(.appAccent)
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
        .navigationTitle("My Files")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showFileImporter = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Color.appAccent)
                }
                .disabled(isUploading)
            }
        }
        .overlay {
            if isLoading && files.isEmpty {
                ProgressView().tint(Color.appAccent)
            } else if files.isEmpty && !isLoading {
                EmptyStateView(systemImage: "tray.and.arrow.up", message: "No uploaded files yet.")
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.audio, .movie, .mpeg4Movie],
            allowsMultipleSelection: true
        ) { result in
            Task { await handleImport(result) }
        }
        .alert("Rename File", isPresented: Binding(
            get: { renamingFile != nil },
            set: { if !$0 { renamingFile = nil } }
        )) {
            TextField("File name", text: $renameText)
            Button("Cancel", role: .cancel) { renamingFile = nil }
            Button("Save") {
                if let file = renamingFile {
                    Task { await rename(file, to: renameText) }
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            files = try await appEnvironment.apiClient.fetchMyUploadedFiles()
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) async {
        guard let urls = try? result.get() else { return }
        isUploading = true
        errorMessage = nil
        defer { isUploading = false }
        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { continue }
            do {
                _ = try await appEnvironment.apiClient.uploadFile(
                    data: data, filename: url.lastPathComponent, mimeType: "application/octet-stream"
                )
            } catch {
                errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
            }
        }
        await load()
    }

    private func rename(_ file: UploadedFileEntry, to newName: String) async {
        renamingFile = nil
        do {
            try await appEnvironment.apiClient.renameUploadedFile(sourceId: file.sourceId, filename: newName)
            await load()
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func delete(_ file: UploadedFileEntry) async {
        do {
            try await appEnvironment.apiClient.deleteUploadedFile(sourceId: file.sourceId)
            files.removeAll { $0.id == file.id }
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }
}
