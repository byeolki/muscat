import MuscatKit
import SwiftUI

struct CreatePlaylistView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.dismiss) private var dismiss

    let onCreated: () async -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var isPublic = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("", text: $name, prompt: Text("Name").foregroundStyle(Color.appTextTertiary))
                        .themedField()
                    TextField("", text: $description, prompt: Text("Description (optional)").foregroundStyle(Color.appTextTertiary))
                        .themedField()

                    Toggle(isOn: $isPublic) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Public Playlist")
                                .foregroundStyle(Color.appTextPrimary)
                            Text("Anyone on this server can see and play it.")
                                .font(.caption)
                                .foregroundStyle(Color.appTextTertiary)
                        }
                    }
                    .tint(Color.appAccent)
                    .padding(14)
                    .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if let errorMessage {
                        ErrorBanner(message: errorMessage)
                    }

                    Button {
                        Task { await create() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Create Playlist")
                        }
                    }
                    .buttonStyle(AccentButtonStyle(fullWidth: true))
                    .disabled(!canSubmit)
                    .opacity(canSubmit ? 1 : 0.5)
                }
                .padding(24)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .themedScreen()
            .navigationTitle("New Playlist")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
        }
    }

    private func create() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            _ = try await appEnvironment.apiClient.createPlaylist(
                name: name,
                description: description.isEmpty ? nil : description,
                isPublic: isPublic
            )
            await onCreated()
            dismiss()
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }
}
