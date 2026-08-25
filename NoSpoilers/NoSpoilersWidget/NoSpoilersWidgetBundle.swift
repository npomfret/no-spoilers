//
//  NoSpoilersWidgetBundle.swift
//  NoSpoilersWidget
//
//  Created by Nick Pomfret on 28/03/2026.
//

import WidgetKit
import SwiftUI
import NoSpoilersCore

@main
struct NoSpoilersWidgetBundle: WidgetBundle {
    /// The extension is launched and killed repeatedly and independently of the app, so this is
    /// also the marker that separates one timeline request from the last.
    init() { AppLog.launched(process: "widget") }

    var body: some Widget {
        NoSpoilersWidget()
        // The Live Activity lives in this bundle rather than a target of its own: ActivityKit
        // matches a running activity to its configuration by attribute type, and one extension is
        // all that needs. See `SessionActivityWidget`.
        SessionActivityWidget()
    }
}
