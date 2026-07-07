import PodoKit
import SwiftUI

/// Lets a playlist owner mint/revoke public "radio" URLs — an infinite-repeat stream of
/// the playlist that anyone with the link can play (VLC, etc.), no login required.
struct RadioTokensView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.dismiss) private var dismiss

    let playlistId: String

    @State private var tokens: [RadioToken] = []
    @State private var isLoading = false
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task { await createToken() }
                    } label: {
                        if isCreating {
                            ProgressView()
                        } else {
                            Label("새 라디오 URL 만들기 (90일 유효)", systemImage: "dot.radiowaves.left.and.right")
                        }
                    }
                    .disabled(isCreating)
                }

                Section("발급된 URL") {
                    ForEach(tokens) { token in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(broadcastURLString(for: token))
                                .font(.caption)
                                .foregroundStyle(token.isActive ? .primary : .secondary)
                                .lineLimit(2)
                            Text(token.isActive ? "만료: \(token.expiresAt.formatted())" : "만료됨 또는 폐기됨")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await revoke(token) }
                            } label: {
                                Label("폐기", systemImage: "trash")
                            }
                        }
                    }
                    if tokens.isEmpty && !isLoading {
                        Text("발급된 라디오 URL이 없습니다.").foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle("라디오 URL")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    /// Built from `serverConfig` directly (plain synchronous property) rather than
    /// through `APIClient.broadcastURL`, which is actor-isolated and would need `await`
    /// — not available inside a synchronous view body.
    private func broadcastURLString(for token: RadioToken) -> String {
        guard let baseURL = appEnvironment.serverConfig.baseURL else { return "" }
        return baseURL.appendingPathComponent("api/v1/broadcast/\(token.token).mp3").absoluteString
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            tokens = try await appEnvironment.apiClient.fetchRadioTokens(playlistId: playlistId)
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func createToken() async {
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }
        do {
            _ = try await appEnvironment.apiClient.createRadioToken(playlistId: playlistId)
            await load()
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func revoke(_ token: RadioToken) async {
        do {
            try await appEnvironment.apiClient.deleteRadioToken(playlistId: playlistId, tokenId: token.id)
            tokens.removeAll { $0.id == token.id }
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }
}
