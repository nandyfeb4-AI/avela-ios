import SwiftUI

/// State selection stays in the domain engine. The scene is presentation only;
/// it never implies that a companion needs care or that a timer proves focus.
struct CompanionView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let profile: CompanionProfile
    let input: CompanionInput
    var compact = false
    var showsPortrait = true

    private var state: CompanionPresentationState { CompanionPresentation.state(for: input) }
    private var stateInk: Color {
        switch state {
        case .steady: return palette.accent
        case .buildingMomentum: return palette.accent
        case .recovering: return Color.appRecovery
        case .needsSpace: return Color.appOverBudget
        }
    }

    var body: some View {
        if profile.companionEnabled {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
            layout {
                if showsPortrait {
                    CompanionPortrait(animal: profile.selectedAnimal, state: state.artworkState.rawValue,
                                      tint: stateInk, size: compact ? 66 : 108)
                        .id(state)
                        .transition(reduceMotion ? .identity : .opacity)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: state)
                }
                VStack(alignment: .leading, spacing: 5) {
                    if !compact {
                        Text("Your \(profile.selectedAnimal.title.lowercased()) companion")
                            .font(.caption).foregroundStyle(Color.appInkSecondary)
                    }
                    Label(state.title, systemImage: state.symbol)
                        .font(.caption.weight(.semibold)).foregroundStyle(stateInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(CompanionPresentation.message(for: input))
                        .font(.subheadline).foregroundStyle(Color.appInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(showsPortrait ? (compact ? 12 : 18) : 0)
            .background {
                if showsPortrait {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(LinearGradient(colors: [palette.atmosphere, palette.surfaceSecondary],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Your \(profile.selectedAnimal.title.lowercased()) companion. \(CompanionPresentation.message(for: input))")
            .accessibilityIdentifier("companion.summary")
            .accessibilityValue(state.title)
        }
    }
}

struct CompanionSelectionView: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selectedAnimal: CompanionAnimal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Same quiet support. Choose your character.")
                .font(.subheadline).foregroundStyle(Color.appInkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(CompanionAnimal.allCases) { animal in
                let selected = selectedAnimal == animal
                Button {
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) { selectedAnimal = animal }
                } label: {
                    let layout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                        : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
                    layout {
                        CompanionPortrait(animal: animal, state: "calm", tint: palette.accent, size: 76)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(animal.title).font(.headline).fontDesign(.rounded)
                                .foregroundStyle(Color.appInk)
                            Text(characterDescription(animal)).font(.subheadline)
                                .foregroundStyle(Color.appInkSecondary)
                        }.fixedSize(horizontal: false, vertical: true)
                        if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 4) }
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.title3).foregroundStyle(palette.accent)
                            .accessibilityHidden(true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                    .background(selected ? palette.accentSoft : palette.surfaceSecondary,
                                in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(selected ? palette.accent : palette.accent.opacity(contrast == .increased ? 0.5 : 0.12),
                                          lineWidth: selected ? 2 : 1)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 24))
                }
                .buttonStyle(RilovaPressStyle())
                .accessibilityIdentifier("companion.select.\(animal.rawValue)")
                .accessibilityLabel(animal.title)
                .accessibilityHint("Select a character for your progress.")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private func characterDescription(_ animal: CompanionAnimal) -> String {
        switch animal {
        case .owl: return "A quiet presence"
        case .fox: return "A little spark"
        case .otter: return "An easygoing friend"
        }
    }
}

/// Shared grounding and lighting coordinates the existing original artwork.
/// This is a still portrait; only real state/selection changes may animate it.
private struct CompanionPortrait: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    let animal: CompanionAnimal
    let state: String
    let tint: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            if reduceTransparency || contrast == .increased {
                palette.heroEnd
            } else {
                RilovaWorldArtwork(scene: animal == .otter ? .coast : .sanctuary)
                    .frame(width: size * 1.28, height: size)
                    .clipped()
            }
            Ellipse().fill(Color(red: 0.88, green: 0.79, blue: 0.59))
                .frame(width: size * 0.78, height: size * 0.14)
                .overlay(Ellipse().strokeBorder(.white.opacity(0.4), lineWidth: 1))
                .offset(y: size * 0.32)
            CompanionArtwork(animal: animal.rawValue, state: state, size: size * 0.88,
                             highResolution: size > 90)
                .offset(y: -size * 0.03)
        }
        .frame(width: size * 1.28, height: size)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: size * 0.30,
                                         bottomLeadingRadius: size * 0.18,
                                         bottomTrailingRadius: size * 0.30,
                                         topTrailingRadius: size * 0.18))
        .accessibilityHidden(true).allowsHitTesting(false)
    }
}
