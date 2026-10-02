enum AppTab: String, CaseIterable, Identifiable {
    case today
    case insights
    case history
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .insights: "Insights"
        case .history: "History"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .insights: "chart.bar"
        case .history: "clock"
        case .settings: "gearshape"
        }
    }

    var placeholderMessage: String {
        switch self {
        case .today: "Your daily habits and attention goals will appear here."
        case .insights: "Your weekly review will appear here as you build a history."
        case .history: "Your habit and attention history will appear here."
        case .settings: "Your preferences will be available here."
        }
    }
}
