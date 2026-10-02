import SwiftUI

/// Temporary shell content; replace with feature-owned views as features ship.
struct ScaffoldPlaceholderView: View {
    let tab: AppTab

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(tab.title)
                    .accessibilityIdentifier("placeholder.\(tab.rawValue)")
            } icon: {
                Image(systemName: tab.systemImage)
            }
        } description: {
            Text(tab.placeholderMessage)
        }
    }
}
