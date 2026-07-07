import PodoKit
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
            Section("Add Library Root") {
                TextField("Server filesystem path (e.g. /music)", text: $newRootPath)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                Button("Add") {
                    Task { await addRoot() }
                }
                .disabled(newRootPath.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Section("Roots") {
                ForEach(roots) { root in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(root.path)
                        HStack {
                            Text(root.enabled ? "Enabled" : "Disabled")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let lastScan = root.lastScanAt {
                                Text("Last scan: \(lastScan.formatted())")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Button("Start Scan") {
                            Task { await triggerScan(rootId: root.id) }
                        }
                        .font(.caption)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await deleteRoot(root) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            Section("Recent Scans") {
                ForEach(scanJobs) { job in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(statusLabel(job.status))
                            Spacer()
                            Text("\(job.processedFiles)/\(job.totalFiles)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("Added \(job.added) · Updated \(job.updated) · Removed \(job.removed)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let error = job.error {
                            Text(error).font(.caption2).foregroundStyle(.red)
                        }
                    }
                }
                if scanJobs.isEmpty && !isLoading {
                    Text("No scan history yet.").foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
        .navigationTitle("Library Scan")
        .refreshable { await load() }
        .task { await load() }
    }

    private func statusLabel(_ status: ScanStatus) -> String {
        switch status {
        case .running: return "Running"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
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
