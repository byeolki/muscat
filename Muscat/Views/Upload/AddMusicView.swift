import MuscatKit
import SwiftUI
import UniformTypeIdentifiers

/// The one place to put music into the library from the phone: paste a link, or
/// send a file.
///
/// Pasting is the path that matters here. On iOS you copy a link in YouTube and
/// switch apps, so the sheet leads with a system `PasteButton` — it hands over
/// the clipboard without the app reading it, so there's no "pasted from" banner
/// and no permission story, and the link is one tap away instead of a
/// long-press-and-paste.
///
/// Downloading is admin-only on the server. Rather than let the request fail with
/// a 403, the link half is simply absent for everyone else; uploading a file is
/// open to any signed-in user.
struct AddMusicView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(AuthStore.self) private var authStore
    @Environment(\.dismiss) private var dismiss

    @State private var link = ""
    @State private var inspection: URLInspection?
    @State private var isInspecting = false
    @State private var keepAsPlaylist = true
    @State private var audioOnly = true

    @State private var isSubmitting = false
    @State private var jobs: [DownloadJob] = []
    @State private var createdPlaylistName: String?
    @State private var errorMessage: String?

    @State private var showFileImporter = false
    @State private var isUploading = false
    @State private var uploadedCount = 0

    private var isAdmin: Bool { authStore.currentUser?.role == .admin }

    private var trimmedLink: String { link.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var looksLikeURL: Bool {
        trimmedLink.hasPrefix("http://") || trimmedLink.hasPrefix("https://")
    }

    private var willCreatePlaylist: Bool {
        (inspection?.isPlaylist ?? false) && keepAsPlaylist
    }

    private var actionTitle: String {
        guard inspection?.isPlaylist == true else { return "Add to Library" }
        return keepAsPlaylist ? "Import as Playlist" : "Add \(inspection?.providerLabel ?? "") Playlist"
    }

    var body: some View {
        NavigationStack {
            List {
                if isAdmin { linkSection }
                fileSection
                if !jobs.isEmpty { jobsSection }
            }
            // `.insetGrouped` is iOS-only; the Mac gets its own grouped default.
            #if os(iOS)
            .listStyle(.insetGrouped)
            #endif
            .themedList()
            .navigationTitle("Add Music")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.appAccent)
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.audio, .movie, .mpeg4Movie],
                allowsMultipleSelection: true
            ) { result in
                Task { await upload(result) }
            }
            .task(id: trimmedLink) { await inspect() }
            .task { await refreshJobs() }
        }
    }

    // MARK: - Link

    @ViewBuilder
    private var linkSection: some View {
        Section {
            HStack(spacing: 10) {
                TextField("", text: $link, prompt: fieldPrompt("youtube.com/playlist?list=…"))
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .foregroundStyle(Color.appTextPrimary)

                if !link.isEmpty {
                    Button {
                        link = ""
                        inspection = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.appTextTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear")
                } else {
                    // Hands over the clipboard without the app reading it.
                    PasteButton(payloadType: URL.self) { urls in
                        guard let url = urls.first else { return }
                        link = url.absoluteString
                    }
                    .labelStyle(.iconOnly)
                    .buttonBorderShape(.capsule)
                    .tint(Color.appAccent)
                }
            }
            .themedCardRow()

            if let inspection {
                LabeledContent(inspection.providerLabel) {
                    Text(inspection.isPlaylist ? "Whole playlist" : "Single track")
                        .foregroundStyle(Color.appTextSecondary)
                }
                .themedCardRow()

                if inspection.isPlaylist {
                    Toggle("Keep as a playlist", isOn: $keepAsPlaylist)
                        .tint(Color.appAccent)
                        .themedCardRow()
                }
            } else if isInspecting {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small).tint(Color.appAccent)
                    Text("Checking link…")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextSecondary)
                }
                .themedCardRow()
            }

            Toggle("Audio only", isOn: $audioOnly)
                .tint(Color.appAccent)
                .themedCardRow()

            Button {
                Task { await submit() }
            } label: {
                HStack {
                    Spacer()
                    if isSubmitting {
                        ProgressView().tint(Color.appAccent)
                    } else {
                        Text(actionTitle)
                            .fontWeight(.semibold)
                            .foregroundStyle(looksLikeURL ? Color.appAccent : Color.appTextTertiary)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .disabled(!looksLikeURL || isSubmitting)
            .themedCardRow()
        } header: {
            sectionHeader("From a link")
        } footer: {
            footerText(
                createdPlaylistName.map { "Created “\($0)”. Tracks are added as they finish downloading." }
                    ?? errorMessage
                    ?? "Anything yt-dlp reads — YouTube, SoundCloud, Bandcamp and the rest. A playlist link keeps its grouping instead of scattering into the library.",
                isError: errorMessage != nil
            )
        }
    }

    // MARK: - Files

    private var fileSection: some View {
        Section {
            Button {
                showFileImporter = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.up.doc.fill")
                        .foregroundStyle(Color.appAccent)
                    Text(isUploading ? "Uploading…" : "Choose Files")
                        .foregroundStyle(Color.appTextPrimary)
                    Spacer()
                    if isUploading {
                        ProgressView().controlSize(.small).tint(Color.appAccent)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isUploading)
            .themedCardRow()
        } header: {
            sectionHeader("From this device")
        } footer: {
            footerText(
                uploadedCount > 0
                    ? "Uploaded \(uploadedCount) file\(uploadedCount == 1 ? "" : "s")."
                    : "Audio or video from Files and iCloud Drive."
            )
        }
    }

    private var jobsSection: some View {
        Section {
            ForEach(jobs) { job in
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.url)
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    HStack(spacing: 6) {
                        Text(job.progressDescription)
                        if let error = job.error {
                            Text("· \(error)")
                                .lineLimit(1)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(job.status == .failed ? Color.appDanger : Color.appTextSecondary)
                }
                .themedCardRow()
            }
        } header: {
            sectionHeader("Downloads")
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.appTextTertiary)
            .kerning(0.8)
            .textCase(.uppercase)
    }

    private func footerText(_ text: String, isError: Bool = false) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(isError ? Color.appDanger : Color.appTextTertiary)
    }

    // MARK: - Actions

    /// Debounced so a pasted link isn't re-inspected on every keystroke of a
    /// hand-typed one. `task(id:)` cancels the previous run for us.
    private func inspect() async {
        guard looksLikeURL else {
            inspection = nil
            return
        }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }

        isInspecting = true
        defer { isInspecting = false }
        inspection = try? await appEnvironment.apiClient.inspectURL(trimmedLink)
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        createdPlaylistName = nil
        defer { isSubmitting = false }

        do {
            if willCreatePlaylist {
                let result = try await appEnvironment.apiClient.importPlaylist(
                    url: trimmedLink, audioOnly: audioOnly
                )
                createdPlaylistName = result.name
            } else {
                _ = try await appEnvironment.apiClient.startDownload(
                    url: trimmedLink, audioOnly: audioOnly
                )
            }
            link = ""
            inspection = nil
            await refreshJobs()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Polls while anything is still running, then stops. The server has no push
    /// channel this view is subscribed to, and a sheet that is open for a minute
    /// shouldn't keep a timer alive after its jobs have settled.
    private func refreshJobs() async {
        for _ in 0..<600 {
            let fetched = (try? await appEnvironment.apiClient.fetchDownloads()) ?? []
            jobs = Array(fetched.prefix(5))
            guard jobs.contains(where: { !$0.isFinished }) else { return }
            try? await Task.sleep(for: .seconds(2))
            if Task.isCancelled { return }
        }
    }

    private func upload(_ result: Result<[URL], Error>) async {
        guard let urls = try? result.get(), !urls.isEmpty else { return }
        isUploading = true
        uploadedCount = 0
        defer { isUploading = false }

        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { continue }
            do {
                _ = try await appEnvironment.apiClient.uploadFile(
                    data: data, filename: url.lastPathComponent,
                    mimeType: "application/octet-stream"
                )
                uploadedCount += 1
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
