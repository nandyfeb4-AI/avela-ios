import SwiftUI

private struct SessionLiveActivityServiceKey: EnvironmentKey {
    static let defaultValue: SessionLiveActivityService? = nil
}

extension EnvironmentValues {
    var sessionLiveActivityService: SessionLiveActivityService? {
        get { self[SessionLiveActivityServiceKey.self] }
        set { self[SessionLiveActivityServiceKey.self] = newValue }
    }
}
