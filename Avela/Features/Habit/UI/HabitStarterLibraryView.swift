import SwiftUI

struct HabitStarterLibraryView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let onSelect: (HabitDraft) -> Void
    @State private var search = ""
    @State private var selectedGroup: HabitStarter.Group?
    @State private var selectedCollection: HabitStarter.Collection?
    @State private var showsCollections = false

    private var query: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var results: [HabitStarter] {
        let source = query.isEmpty ? selectedCollection?.starters ?? HabitStarter.library : HabitStarter.library
        return source.filter { starter in
            let matchesGroup = !query.isEmpty || selectedCollection != nil || selectedGroup == nil || starter.group == selectedGroup
            return matchesGroup && (query.isEmpty || starter.draft.name.localizedStandardContains(query)
                || starter.description.localizedStandardContains(query)
                || starter.group.rawValue.localizedStandardContains(query)
                || starter.trackingLabel.localizedStandardContains(query))
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                if query.isEmpty {
                    introduction
                    if showsCollections {
                        collections
                    } else if let collection = selectedCollection {
                        collectionHeader(collection)
                    } else {
                        categoryShelf
                    }
                }
                if !showsCollections || !query.isEmpty {
                    if results.isEmpty {
                        ContentUnavailableView.search(text: search)
                    } else {
                        ForEach(HabitStarter.Group.allCases, id: \.self) { group in
                            let starters = results.filter { $0.group == group }
                            if !starters.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(selectedCollection == nil ? group.rawValue : group.rawValue.uppercased())
                                        .font(selectedCollection == nil ? .title2.weight(.bold) : .caption.weight(.semibold))
                                        .fontDesign(.rounded)
                                        .foregroundStyle(selectedCollection == nil ? Color.appInk : Color.appInkSecondary)
                                        .accessibilityAddTraits(.isHeader)
                                    ForEach(starters) { starter in
                                        starterCard(starter)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .searchable(text: $search, prompt: "Find your next habit")
        .scrollDismissesKeyboard(.interactively)
        .appThemeCanvas()
        .navigationTitle("Habit Ideas")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Small starts.\nYour kind of life.")
                .font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                .tracking(-0.7)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("40 ideas to make your own. Choose one, then adjust it before saving.")
                .font(.subheadline).foregroundStyle(Color.appInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                showsCollections.toggle()
                selectedCollection = nil
                selectedGroup = nil
            } label: {
                Label(showsCollections ? "Explore all ideas" : "Explore routine starters",
                      systemImage: showsCollections ? "square.grid.2x2" : "square.stack.3d.up.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .foregroundStyle(palette.accent)
            }
            .buttonStyle(StarterPressStyle())
            .accessibilityIdentifier("habitStarter.collections")
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: palette.welcomeColors,
                    startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay(alignment: .topTrailing) {
            Image(systemName: "sparkle")
                .font(.system(size: 42, weight: .ultraLight))
                .foregroundStyle(palette.accent.opacity(0.12))
                .padding(18).accessibilityHidden(true).allowsHitTesting(false)
        }
    }

    private var categoryShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Explore a little").font(.headline)
                Spacer()
                if selectedGroup != nil {
                    Button("Show all") { selectedGroup = nil }
                        .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                        .accessibilityIdentifier("habitStarter.showAll")
                }
            }
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(HabitStarter.Group.allCases, id: \.self) { group in
                        Button {
                            selectedGroup = selectedGroup == group ? nil : group
                        } label: {
                            VStack(spacing: 9) {
                                StarterCategoryArtwork(group: group)
                                    .frame(width: 94, height: 80)
                                Text(group.rawValue)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.appInk)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(width: dynamicTypeSize.isAccessibilitySize ? 150 : 100)
                            }
                            .padding(5)
                            .background(selectedGroup == group ? palette.accentSoft : .clear,
                                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                        .buttonStyle(StarterPressStyle())
                        .accessibilityLabel("\(group.rawValue). \(group.subtitle)")
                        .accessibilityAddTraits(selectedGroup == group ? .isSelected : [])
                        .accessibilityIdentifier("habitStarter.group.\(group.symbol)")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var collections: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("A few ideas that belong together")
                .font(.title2.weight(.bold)).fontDesign(.rounded)
                .accessibilityAddTraits(.isHeader)
            Text("Start one habit at a time. Later, group your saved habits into a routine from Today.")
                .font(.subheadline).foregroundStyle(Color.appInkSecondary)
            ForEach(HabitStarter.collections) { collection in
                Button {
                    selectedCollection = collection
                    selectedGroup = nil
                    showsCollections = false
                } label: {
                    HStack(alignment: .center, spacing: 18) {
                        Image(systemName: collection.symbol)
                            .font(.system(size: 30, weight: .light))
                            .foregroundStyle(palette.accent)
                            .frame(width: 64, height: 76)
                            .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: 20))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(collection.name).font(.title3.weight(.bold)).fontDesign(.rounded)
                                .foregroundStyle(Color.appInk)
                            Text(collection.subtitle).font(.subheadline).foregroundStyle(Color.appInkSecondary)
                            Text("\(collection.starterIDs.count) editable ideas")
                                .font(.caption.weight(.semibold)).foregroundStyle(palette.accent)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right").foregroundStyle(palette.accent).accessibilityHidden(true)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
                }
                .buttonStyle(StarterPressStyle())
                .accessibilityIdentifier("habitStarter.collection.\(collection.id)")
            }
        }
    }

    private func collectionHeader(_ collection: HabitStarter.Collection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(collection.name, systemImage: collection.symbol)
                .font(.title2.weight(.bold)).fontDesign(.rounded)
                .foregroundStyle(Color.appInk).accessibilityAddTraits(.isHeader)
            Text("Choose one idea to review. Nothing is created until you save.")
                .font(.subheadline).foregroundStyle(Color.appInkSecondary)
            Button("Back to all ideas") { selectedCollection = nil }
                .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
        }
    }

    private func starterCard(_ starter: HabitStarter) -> some View {
        Button {
            onSelect(starter.draft)
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 13) {
                    HabitIconBadge(symbol: starter.draft.iconName).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(starter.draft.name).font(.title3.weight(.semibold)).fontDesign(.rounded)
                            .foregroundStyle(Color.appInk)
                        Text(starter.description).font(.subheadline)
                            .foregroundStyle(Color.appInkSecondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "plus").font(.body.weight(.semibold))
                        .foregroundStyle(palette.accent).padding(.top, 9).accessibilityHidden(true)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { starterMetadata(starter) }
                    VStack(alignment: .leading, spacing: 8) { starterMetadata(starter) }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .strokeBorder(palette.accent.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(StarterPressStyle())
        .accessibilityLabel("Use \(starter.draft.name). \(starter.description). \(starter.trackingLabel). \(HabitScheduleFormatter.description(for: starter.draft.schedule))")
        .accessibilityHint("Opens an editable draft. No habit is created yet.")
        .accessibilityIdentifier("habitStarter." + starter.id)
    }

    @ViewBuilder
    private func starterMetadata(_ starter: HabitStarter) -> some View {
        Label(starter.trackingLabel, systemImage: starter.draft.quantityTarget?.unit == .minutes ? "timer" : "checkmark.circle")
            .font(.caption.weight(.medium)).foregroundStyle(palette.accent)
        Text(HabitScheduleFormatter.description(for: starter.draft.schedule))
            .font(.caption).foregroundStyle(Color.appInkSecondary)
    }
}

/// Original category compositions assembled from native, decorative symbols.
/// The category label carries meaning; no illustration encodes progress.
private struct StarterCategoryArtwork: View {
    let group: HabitStarter.Group
    private var theme: AppTheme {
        switch group {
        case .move: .ember
        case .wellbeing: .gold
        case .learn: .plum
        case .create: .coral
        case .home: .sapphire
        case .connect: .rose
        case .makeSpace: .tidewater
        case .money: .forest
        }
    }
    var body: some View {
        let colors = AppPalette(theme: theme)
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [colors.accentSoft, colors.atmosphere],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().fill(colors.accent.opacity(0.10)).frame(width: 55, height: 55).offset(x: 24, y: -15)
            Ellipse().stroke(colors.accent.opacity(0.14), lineWidth: 1)
                .frame(width: 94, height: 40).rotationEffect(.degrees(-25)).offset(x: -12, y: 20)
            Image(systemName: group.symbol)
                .font(.system(size: 34, weight: .light)).symbolRenderingMode(.hierarchical)
                .foregroundStyle(colors.accent)
            Image(systemName: "sparkle").font(.system(size: 12, weight: .light))
                .foregroundStyle(colors.accent.opacity(0.6)).offset(x: 28, y: 21)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct StarterPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
