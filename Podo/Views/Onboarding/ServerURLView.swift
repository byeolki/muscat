import PodoKit
import SwiftUI

struct ServerURLView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    let onConfigured: () -> Void

    @State private var urlText = ""
    @State private var isChecking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 44))
                        .foregroundStyle(.tint)
                    Text("Podo 서버 주소 입력")
                        .font(.title2.bold())
                    Text("자체 호스팅 중인 Podo 서버의 주소를 입력하세요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                TextField("https://music.example.com", text: $urlText)
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await verifyAndSave() }
                } label: {
                    if isChecking {
                        ProgressView()
                    } else {
                        Text("연결하기")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || isChecking)
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
    }

    private func verifyAndSave() async {
        guard let url = ServerConfig.normalize(urlText) else {
            errorMessage = "올바른 서버 주소를 입력하세요."
            return
        }
        isChecking = true
        errorMessage = nil
        defer { isChecking = false }

        guard await appEnvironment.verifyServerURL(url) else {
            errorMessage = "서버에 연결할 수 없습니다. 주소를 확인하세요."
            return
        }
        await appEnvironment.saveServerURL(url)
        onConfigured()
    }
}
