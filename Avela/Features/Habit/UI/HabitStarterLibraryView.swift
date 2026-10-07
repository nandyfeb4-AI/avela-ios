import SwiftUI

struct HabitStarterLibraryView: View {
    @Environment(\.appPalette) private var palette
    let onSelect: (HabitDraft) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var results: [HabitStarter] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return HabitStarter.library.filter {
            query.isEmpty || $0.draft.name.localizedStandardContains(query)
                || $0.description.localizedStandardContains(query)
                || $0.group.rawValue.localizedStandardContains(query)
        }
    }

    var body: some View {
        List {
            if search.isEmpty {
                Section {
                    Text("Pick an idea. Edit it before Save.")
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(HabitStarter.Group.allCases, id: \.self) { group in
                let starters = results.filter { $0.group == group }
                if !starters.isEmpty {
                    Section(group.rawValue) {
                        ForEach(starters) { starter in
                            Button {
                                onSelect(starter.draft)
                                dismiss()
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: starter.draft.iconName)
                                        .font(.title3).foregroundStyle(palette.accent)
                                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                                        .frame(width: 44).accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(starter.draft.name).font(.headline).foregroundStyle(.primary)
                                        Text(starter.description).font(.subheadline).foregroundStyle(.secondary)
                                        Text(HabitScheduleFormatter.description(for: starter.draft.schedule))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .contentShape(Rectangle())
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Use \(starter.draft.name). \(starter.description)")
                            .accessibilityIdentifier("habitStarter." + starter.id)
                        }
                    }
                }
            }
        }
        .overlay {
            if results.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
        .searchable(text: $search, prompt: "Find an idea")
        .scrollDismissesKeyboard(.interactively)
        .appThemeCanvas()
        .navigationTitle("Habit Ideas")
        .navigationBarTitleDisplayMode(.inline)
    }
}
