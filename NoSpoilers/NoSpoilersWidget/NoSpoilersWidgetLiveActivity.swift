//
//  NoSpoilersWidgetLiveActivity.swift
//  NoSpoilersWidget
//
//  Created by Nick Pomfret on 28/03/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct NoSpoilersWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct NoSpoilersWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NoSpoilersWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension NoSpoilersWidgetAttributes {
    fileprivate static var preview: NoSpoilersWidgetAttributes {
        NoSpoilersWidgetAttributes(name: "World")
    }
}

extension NoSpoilersWidgetAttributes.ContentState {
    fileprivate static var smiley: NoSpoilersWidgetAttributes.ContentState {
        NoSpoilersWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: NoSpoilersWidgetAttributes.ContentState {
         NoSpoilersWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: NoSpoilersWidgetAttributes.preview) {
   NoSpoilersWidgetLiveActivity()
} contentStates: {
    NoSpoilersWidgetAttributes.ContentState.smiley
    NoSpoilersWidgetAttributes.ContentState.starEyes
}
