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
            Section("라이브러리 루트 추가") {
                TextField("서버 파일 시스템 경로 (예: /music)", text: $newRootPath)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                Button("추가") {
                    Task { await addRoot() }
                }
                .disabled(newRootPath.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Section("루트") {
                ForEach(roots) { root in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(root.path)
                        HStack {
                            Text(root.enabled ? "활성" : "비활성")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let lastScan = root.lastScanAt {
                                Text("마지막 스캔: \(lastScan.formatted())")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Button("스캔 시작") {
                            Task { await triggerScan(rootId: root.id) }
                        }
                        .font(.caption)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await deleteRoot(root) }
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                }
            }

            Section("최근 스캔 기록") {
                ForEach(scanJobs) { job in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(statusLabel(job.status))
                            Spacer()
                            Text("\(job.processedFiles)/\(job.totalFiles)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("추가 \(job.added) · 갱신 \(job.updated) · 제거 \(job.removed)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let error = job.error {
                            Text(error).font(.caption2).foregroundStyle(.red)
                        }
                    }
                }
                if scanJobs.isEmpty && !isLoading {
                    Text("스캔 기록이 없습니다.").foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }
        }
        .navigationTitle("라이브러리 스캔")
        .refreshable { await load() }
        .task { await load() }
    }

    private func statusLabel(_ status: ScanStatus) -> String {
        switch status {
        case .running: return "진행 중"
        case .completed: return "완료"
        case .failed: return "실패"
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
