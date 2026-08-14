import SwiftUI

/// Renders a country flag from bundled SVG assets at a fixed height.
/// Width is automatically set to the standard 4:3 flag aspect ratio.
/// A nil `countryCode` means the feed named a Grand Prix this app cannot map to a country; the
/// chequered flag stands in for it. That is a presentation choice about a known-unknown, which is
/// why it lives here and not in the model.
public struct FlagImage: View {
    let countryCode: String?
    let height: CGFloat

    public init(countryCode: String?, height: CGFloat) {
        self.countryCode = countryCode
        self.height = height
    }

    public var body: some View {
        if let countryCode {
            Image("flag-\(countryCode.lowercased())", bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(width: height * 4 / 3, height: height)
        } else {
            Text(verbatim: "🏁").frame(width: height * 4 / 3, height: height)
        }
    }
}
