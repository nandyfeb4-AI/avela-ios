import SwiftUI
import WidgetKit

@main
struct AvelaWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuickLogWidget()
        RoutineLogWidget()
        PhoneFreeLiveActivityWidget()
    }
}
