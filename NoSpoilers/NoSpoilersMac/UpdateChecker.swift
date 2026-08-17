import Foundation
import Combine
import NoSpoilersCore

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

    private static let latestReleaseURL = URL(
        string: "https://api.github.com/repos/npomfret/no-spoilers/releases/latest")!

    /// Asks GitHub for the newest published release and records whether it is ahead of us.
    ///
    /// Every step used to be a `try?` that returned on failure, which left `isUpdateAvailable`
    /// at `false` — **the same state as a successful check that found nothing new**, and the same
    /// empty menu bar. There is no UI for "could not check" and this does not add one; what it
    /// adds is a line saying which of the two happened, because without Sparkle the check being
    /// silently broken is indistinguishable from the app being current.
    func check() async {
        // App Store handles updates; the brew-upgrade banner is irrelevant there.
        guard !Self.isAppStoreBuild else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: Self.latestReleaseURL)
            // GitHub answers an unauthenticated rate limit with 403 and a JSON body of its own,
            // which decodes to nothing we recognise and used to read as "no new release".
            try response.requireSuccess()
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let remote  = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            let current = AppVersion.marketing
            latestVersion = remote
            currentVersion = current
            isUpdateAvailable = isNewer(remote, than: current)
            AppLog.update.notice("update check complete", ["latest": remote,
                                                           "current": current,
                                                           "available": isUpdateAvailable])
        } catch {
            AppLog.update.error("update check failed", ["error": LogValue.error(error)])
        }
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
