import SwiftUI

/// Renders a country flag from bundled SVG assets at a fixed height.
/// Width is automatically set to the standard 4:3 flag aspect ratio.
public struct FlagImage: View {
    let countryCode: String
    let height: CGFloat

    public init(countryCode: String, height: CGFloat) {
        self.countryCode = countryCode
        self.height = height
    }

    public var body: some View {
        if countryCode.isEmpty {
            Text("🏁").frame(width: height * 4 / 3, height: height)
        } else {
            Image("flag-\(countryCode.lowercased())", bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(width: height * 4 / 3, height: height)
        }
    }
}
