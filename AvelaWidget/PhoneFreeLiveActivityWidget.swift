import ActivityKit
import SwiftUI
import WidgetKit

/// A time-bound companion for a real phone-free session. Timer expiry never
/// records success: the user returns to Avela to confirm the session outcome.
struct PhoneFreeLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PhoneFreeActivityAttributes.self) { context in
            HStack(spacing: 12) {
                sessionArtwork(context, size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Phone-free session").font(.headline)
                    if context.isStale {
                        Text("Time elapsed · confirm in Avela").font(.subheadline)
                    } else {
                        countdown(context).font(.title2.weight(.semibold))
                        Text("Tap to check in with Avela").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding()
            .widgetURL(WidgetDeepLink.today.url)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    sessionArtwork(context, size: 48)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.isStale {
                        Text("Time elapsed").font(.headline)
                    } else {
                        countdown(context).font(.title2.weight(.semibold))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Phone-free session").font(.headline)
                        Text(context.isStale ? "Time elapsed · confirm in Avela" : "Tap to check in with Avela")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                sessionArtwork(context, size: 22)
            } compactTrailing: {
                Group {
                    if context.isStale {
                        Text("Check in").font(.caption2)
                    } else {
                        countdown(context).font(.caption.monospacedDigit())
                    }
                }
                .frame(width: 64)
            } minimal: {
                sessionArtwork(context, size: 20)
            }
            .widgetURL(WidgetDeepLink.today.url)
        }
    }

    @ViewBuilder
    private func sessionArtwork(_ context: ActivityViewContext<PhoneFreeActivityAttributes>, size: CGFloat) -> some View {
        if let animal = context.state.animal,
           ["owl", "fox", "otter"].contains(animal) {
            CompanionArtwork(animal: animal, state: context.isStale ? "calm" : "focused", size: size)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "hourglass")
                .font(.system(size: size * 0.7))
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }

    private func countdown(_ context: ActivityViewContext<PhoneFreeActivityAttributes>) -> some View {
        // A malformed restored interval cannot form an invalid ClosedRange.
        let start = context.attributes.startedAt
        let end = max(start, context.attributes.expectedEnd)
        return Text(timerInterval: start...end, countsDown: true, showsHours: true)
            .monospacedDigit()
            .accessibilityLabel("Time remaining")
    }
}
