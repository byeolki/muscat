import MuscatKit
import SwiftUI

/// Links a playlist to one on an external platform and lets the server keep it
/// topped up. One-way and additive — nothing local is ever deleted because it
/// disappeared upstream, which is usually the reason to keep a copy at all.
struct PlaylistSyncView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.dismiss) private var dismiss

    let playlistId: String
    let onChanged: () async -> Void

    @State private var subscription: PlaylistSubscription?
    @State private var sourceURL = ""
    @State private var intervalMinutes = 360
    @State private var audioOnly = true
    @State private var loadState = LoadableState<PlaylistSubscription?>()
    @State private var isSaving = false
    @State private var isSyncing = false
    @State private var lastResult: PlaylistSyncResult?

    private static let intervals: [(minutes: Int, label: String)] = [
        (60, "Every hour"),
        (360, "Every 6 hours"),
        (720, "Every 12 hours"),
        (1440, "Once a day"),
        (10080, "Once a week"),
    ]

    private var canSave: Bool {
        !sourceURL.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "", text: $sourceURL,
                        prompt: Text("https://youtube.com/playlist?list=…").foregroundStyle(Color.appTextTertiary)
                    )
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .themedRow()

                    Picker("Check for new items", selection: $intervalMinutes) {
                        ForEach(Self.intervals, id: \.minutes) { option in
                            Text(option.label).tag(option.minutes)
                        }
                    }
                    .themedRow()

                    Toggle("Audio only", isOn: $audioOnly)
                        .tint(Color.appAccent)
                        .themedRow()
                } header: {
                    sectionHeader("Source playlist")
                } footer: {
                    Text("Any playlist yt-dlp can read — YouTube, SoundCloud, Bandcamp and the rest. New items are downloaded and appended; tracks already here are left alone.")
                        .font(.caption)
                        .foregroundStyle(Color.appTextTertiary)
                }

                if let subscription {
                    Section {
                        LabeledContent("Status") {
                            Text(statusText(for: subscription))
                                .foregroundStyle(subscription.lastStatus == .failed ? Color.appDanger : Color.appTextSecondary)
                        }
                        .themedRow()
                        LabeledContent("Tracks added") {
                            Text("\(subscription.addedCount)")
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        .themedRow()
                        if let error = subscription.lastError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(Color.appDanger)
                                .themedRow()
                        }
                    } header: {
                        sectionHeader("Last run")
                    }
                }

                if let lastResult {
                    Section {
                        Text("+\(lastResult.added) added · \(lastResult.skipped) already here" +
                             (lastResult.failed > 0 ? " · \(lastResult.failed) failed" : ""))
                            .font(.footnote)
                            .foregroundStyle(Color.appAccent)
                            .themedRow()
                    }
                }

                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text(subscription == nil ? "Link Playlist" : "Update")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(AccentButtonStyle(fullWidth: true))
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    if subscription != nil {
                        Button {
                            Task { await syncNow() }
                        } label: {
                            if isSyncing {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(SurfaceButtonStyle())
                        .disabled(isSyncing)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                        Button(role: .destructive) {
                            Task { await unlink() }
                        } label: {
                            Text("Stop Syncing")
                                .foregroundStyle(Color.appDanger)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SurfaceButtonStyle())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }

                if let errorMessage = loadState.errorMessage {
                    ErrorBanner(message: errorMessage)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .themedList()
            .navigationTitle("Auto-sync")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
            .task { await load() }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.appTextTertiary)
            .kerning(0.8)
    }

    private func statusText(for subscription: PlaylistSubscription) -> String {
        if subscription.lastStatus == .running { return "Syncing now…" }
        guard let lastSyncedAt = subscription.lastSyncedAt else { return "Not synced yet" }
        return lastSyncedAt.formatted(.relative(presentation: .named))
    }

    private func load() async {
        let result = await loadState.run {
            try await appEnvironment.apiClient.fetchSubscription(playlistId: playlistId)
        }
        guard let result, let existing = result else { return }
        subscription = existing
        sourceURL = existing.sourceUrl
        intervalMinutes = existing.intervalMinutes
        audioOnly = existing.audioOnly
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            subscription = try await appEnvironment.apiClient.setSubscription(
                playlistId: playlistId,
                sourceURL: sourceURL.trimmingCharacters(in: .whitespaces),
                intervalMinutes: intervalMinutes,
                audioOnly: audioOnly
            )
            await onChanged()
        } catch {
            loadState.fail(error)
        }
    }

    private func syncNow() async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            lastResult = try await appEnvironment.apiClient.syncSubscriptionNow(playlistId: playlistId)
            await load()
            await onChanged()
        } catch {
            loadState.fail(error)
        }
    }

    private func unlink() async {
        do {
            try await appEnvironment.apiClient.deleteSubscription(playlistId: playlistId)
            subscription = nil
            lastResult = nil
            sourceURL = ""
        } catch {
            loadState.fail(error)
        }
    }
}
