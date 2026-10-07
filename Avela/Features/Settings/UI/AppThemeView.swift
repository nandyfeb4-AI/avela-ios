import SwiftUI

struct AppThemeView: View {
    @State private var viewModel: AppThemeViewModel
    var onThemeChanged: () -> Void

    init(repository: AppearanceRepository, onThemeChanged: @escaping () -> Void = {}) {
        _viewModel = State(initialValue: AppThemeViewModel(repository: repository))
        self.onThemeChanged = onThemeChanged
    }

    var body: some View {
        List {
            Section {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        if viewModel.select(theme) { onThemeChanged() }
                    } label: {
                        HStack(spacing: 14) {
                            ThemeLandscape(theme: theme)
                                .frame(width: 72, height: 54)
                                .background(AppPalette(theme: theme).heroGradient)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(theme.title).font(.body.weight(.semibold)).foregroundStyle(Color.appInk)
                                Text(theme.description).font(.caption).foregroundStyle(Color.appInkSecondary)
                            }
                            Spacer(minLength: 8)
                            if viewModel.selectedTheme == theme {
                                Image(systemName: "checkmark").font(.body.weight(.semibold))
                                    .accessibilityHidden(true)
                            }
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .disabled(!viewModel.hasLoaded)
                    .accessibilityIdentifier("appearance.theme.\(theme.rawValue)")
                    .accessibilityLabel("\(theme.title), \(theme.description)")
                    .accessibilityAddTraits(viewModel.selectedTheme == theme ? [.isSelected] : [])
                    .accessibilityValue(viewModel.selectedTheme == theme ? "Selected" : "Not selected")
                }
            } header: { Text("Choose Your Theme") } footer: {
                Text("Themes follow your iPhone's light or dark appearance. Attention warnings and recovery keep their familiar colors. Widgets and session activities keep Avela's original Tidewater palette.")
            }
        }
        .appThemeCanvas()
        .navigationTitle("App Theme")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load() }
        .alert("Theme Couldn't Be Updated", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("Try Again") { viewModel.load() }
            Button("Cancel", role: .cancel) {}
        } message: { Text(viewModel.errorMessage ?? "") }
    }
}
