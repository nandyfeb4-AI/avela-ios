import ActivityKit
import Foundation

@MainActor
final class ActivityKitSessionAdapter: SessionLiveActivityAdapter {
    var areEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    var activities: [SessionLiveActivityDescriptor] {
        currentActivities.map {
            SessionLiveActivityDescriptor(sessionID: $0.attributes.sessionID,
                startedAt: $0.attributes.startedAt, expectedEnd: $0.attributes.expectedEnd,
                animal: $0.content.state.animal, isFocusSession: $0.content.state.isFocusSession == true)
        }
    }

    func request(_ descriptor: SessionLiveActivityDescriptor) throws {
        let attributes = PhoneFreeActivityAttributes(sessionID: descriptor.sessionID,
            startedAt: descriptor.startedAt, expectedEnd: descriptor.expectedEnd)
        _ = try Activity.request(attributes: attributes, content: content(descriptor), pushType: nil)
    }

    func update(_ descriptor: SessionLiveActivityDescriptor) async {
        for activity in currentActivities where activity.attributes.sessionID == descriptor.sessionID {
            if activity.content.state.animal != descriptor.animal || (activity.content.state.isFocusSession == true) != descriptor.isFocusSession {
                await activity.update(content(descriptor))
            }
        }
    }

    func end(sessionID: UUID) async {
        for activity in currentActivities where activity.attributes.sessionID == sessionID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private var currentActivities: [Activity<PhoneFreeActivityAttributes>] {
        Activity<PhoneFreeActivityAttributes>.activities.filter {
            $0.activityState == .active || $0.activityState == .stale
        }
    }

    private func content(_ descriptor: SessionLiveActivityDescriptor) -> ActivityContent<PhoneFreeActivityAttributes.ContentState> {
        ActivityContent(state: PhoneFreeActivityAttributes.ContentState(animal: descriptor.animal, isFocusSession: descriptor.isFocusSession),
            staleDate: descriptor.expectedEnd)
    }
}
