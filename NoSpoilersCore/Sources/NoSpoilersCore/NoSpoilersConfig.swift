import Foundation

public enum NoSpoilersConfig {
    public static let appGroupID = "group.pomocorp.no-spoilers"

    /// The widget's `StaticConfiguration` kind.
    ///
    /// Shared because two targets need the same literal: the widget declares it, and the app asks
    /// `WidgetCenter` whether a widget of this kind is installed. Written out twice it would be a
    /// silent failure — the app would decide nobody has the widget and nag every user forever.
    ///
    /// The value is load-bearing on device. Changing it makes every installed widget a different
    /// widget, so it must not be renamed to match a Swift type.
    public static let widgetKind = "NoSpoilersWidget"
}
