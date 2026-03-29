import Foundation
import Combine

@MainActor
final class UpdateChecker: ObservableObject {
    @Published private(set) var isUpdateAvailable = false
    @Published private(set) var latestVersion: String = ""
    @Published private(set) var currentVersion: String = ""

    /// True when the app was installed from the Mac App Store.
    /// App Store builds carry a receipt file; Homebrew / Developer ID builds do not.
    static var isAppStoreBuild: Bool {
        // App Store builds contain a receipt at this fixed path inside the bundle.
        // Avoids the deprecated appStoreReceiptURL API.
        let receipt = Bundle.main.bundleURL
            .appendingPathComponent("Contents/_MASReceipt/receipt")
        return FileManager.default.fileExists(atPath: receipt.path)
    }

    func check() async {
        // App Store handles updates; the brew-upgrade banner is irrelevant there.
        guard !Self.isAppStoreBuild else { return }
        guard let url = URL(string: "https://api.github.com/repos/npomfret/no-spoilers/releases/latest") else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        guard let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) else { return }
        let remote  = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        latestVersion = remote
        currentVersion = current
        isUpdateAvailable = isNewer(remote, than: current)
    }

    private func isNewer(_ remote: String, than current: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let c = current.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, c.count) {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv != cv { return rv > cv }
        }
        return false
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    enum CodingKeys: String, CodingKey { case tagName = "tag_name" }
}
