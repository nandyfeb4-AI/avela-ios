import SwiftUI
import UIKit

/// State selection remains in the domain engine; this view only renders the
/// matching pose and a brief transition. No idle loop or mascot-care mechanics.
struct CompanionView: View {
    @Environment(\.appPalette) private var palette
    let profile: CompanionProfile
    let input: CompanionInput
    var compact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var state: CompanionState { CompanionStateEngine.state(for: input) }

    private var stateLabel: String {
        switch state {
        case .calm: return "Calm"
        case .focused: return "Focused"
        case .nearLimit: return "Close to a logged limit"
        case .overloaded: return "Time for a pause"
        case .recovering: return "Rebuilding momentum"
        case .celebrating: return "Celebrating progress"
        }
    }

    var body: some View {
        if profile.companionEnabled {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
            layout {
                CompanionArtwork(animal: profile.selectedAnimal.rawValue, state: state.rawValue, size: compact ? 48 : 80)
                    .id(state)
                    .transition(reduceMotion ? .identity : .opacity)
                    .scaleEffect(!reduceMotion && state == .celebrating ? 1.04 : 1)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: state)
                VStack(alignment: .leading, spacing: 4) {
                    if !compact {
                        Text("Your \(profile.selectedAnimal.title.lowercased()) companion")
                            .font(.caption).foregroundStyle(Color.appInkSecondary)
                    }
                    Text(CompanionStateEngine.message(for: input))
                        .font(.subheadline).foregroundStyle(Color.appInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Your \(profile.selectedAnimal.title.lowercased()) companion. \(CompanionStateEngine.message(for: input))")
            .accessibilityIdentifier("companion.summary")
            .accessibilityValue(stateLabel)
        }
    }
}

struct CompanionSelectionView: View {
    @Binding var selectedAnimal: CompanionAnimal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("A quiet companion for your progress.").foregroundStyle(.secondary)
            ForEach(CompanionAnimal.allCases) { animal in
                Button { selectedAnimal = animal } label: {
                    HStack(spacing: 12) {
                        CompanionArtwork(animal: animal.rawValue, state: "calm", size: 56)
                        Text(animal.title)
                        Spacer()
                        if selectedAnimal == animal { Image(systemName: "checkmark").accessibilityHidden(true) }
                    }
                    .frame(minHeight: 48)
                    .padding(.horizontal, 12)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("companion.select.\(animal.rawValue)")
                .accessibilityAddTraits(selectedAnimal == animal ? .isSelected : [])
            }
        }
    }
}
