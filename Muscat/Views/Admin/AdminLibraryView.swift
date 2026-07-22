import MuscatKit
import SwiftUI

struct AdminLibraryView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    @State private var roots: [LibraryRoot] = []
    @State private var scanJobs: [ScanJob] = []
    @State private var newRootPath = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    TextField("", text: $newRootPath, prompt: Text("Server filesystem path (e.g. /music)").foregroundStyle(Color.appTextTertiary))
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                        .themedField()
                    Button {
                        Task { await addRoot() }
                    } label: {
                        Text("Add Root")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AccentButtonStyle(fullWidth: true))
                    .disabled(newRootPath.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(newRootPath.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } header: {
                sectionHeader("Add Library Root")
            }

            Section {
                ForEach(roots) { root in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(root.path)
                            .font(.subheadline.weight(.medium).monospaced())
                            .foregroundStyle(Color.appTextPrimary)
                        HStack(spacing: 8) {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(root.enabled ? Color.appAccent : Color.appTextTertiary)
                                    .frame(width: 6, height: 6)
                                Text(root.enabled ? "Enabled" : "Disabled")
                            }
                            if let lastScan = root.lastScanAt {
                                Text("· Last scan \(lastScan.formatted())")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(Color.appTextTertiary)
                        Button("Start Scan") {
                            Task { await triggerScan(rootId: root.id) }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appAccent)
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                    .themedRow()
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await deleteRoot(root) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                if roots.isEmpty && !isLoading {
                    Text("No library roots configured.")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextTertiary)
                        .themedRow()
                }
            } header: {
                sectionHeader("Roots")
            }

            Section {
                ForEach(scanJobs) { job in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            statusChip(job.status)
                            Spacer()
                            Text("\(job.processedFiles)/\(job.totalFiles)")
                                .font(.caption)
                                .foregroundStyle(Color.appTextTertiary)
                                .monospacedDigit()
                        }
                        Text("Added \(job.added) · Updated \(job.updated) · Removed \(job.removed)")
                            .font(.caption2)
                            .foregroundStyle(Color.appTextSecondary)
                        if let error = job.error {
                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(Color.appDanger)
                        }
                    }
                    .padding(.vertical, 2)
                    .themedRow()
                }
                if scanJobs.isEmpty && !isLoading {
                    Text("No scan history yet.")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextTertiary)
                        .themedRow()
                }
            } header: {
                sectionHeader("Recent Scans")
            }

            if let errorMessage {
                ErrorBanner(message: errorMessage)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .themedList()
        .navigationTitle("Library Scan")
        .refreshable { await load() }
        .task { await load() }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.appTextTertiary)
            .kerning(0.8)
    }

    private func statusChip(_ status: ScanStatus) -> some View {
        let (label, color): (String, Color) = switch status {
        case .running: ("Running", Color.appAccent)
        case .completed: ("Completed", Color.appTextSecondary)
        case .failed: ("Failed", Color.appDanger)
        }
        return Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let rootsResult = appEnvironment.apiClient.fetchLibraryRoots()
            async let jobsResult = appEnvironment.apiClient.fetchScanJobs()
            roots = try await rootsResult
            scanJobs = Array(try await jobsResult.reversed())
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func addRoot() async {
        errorMessage = nil
        do {
            _ = try await appEnvironment.apiClient.addLibraryRoot(path: newRootPath)
            newRootPath = ""
            await load()
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func deleteRoot(_ root: LibraryRoot) async {
        do {
            try await appEnvironment.apiClient.deleteLibraryRoot(id: root.id)
            roots.removeAll { $0.id == root.id }
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func triggerScan(rootId: String) async {
        errorMessage = nil
        do {
            try await appEnvironment.apiClient.triggerLibraryScan(rootId: rootId)
            await load()
        } catch {
            errorMessage = (error as? APIClientError)?.errorDescription ?? error.localizedDescription
        }
    }
}
