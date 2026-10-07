import XCTest
import SwiftData
import SwiftUI
import UIKit
@testable import Avela

@MainActor
final class AppThemeTests: XCTestCase {
    func testMissingAppearanceUsesOriginalThemeWithoutWritingARecord() throws {
        let container = try AppPersistence.makeContainer(inMemory: true)
        let repository = SwiftDataAppearanceRepository(context: container.mainContext)
        XCTAssertEqual(try repository.theme(), .tidewater)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<AppAppearanceRecord>()), 0)
    }

    func testChangingThemeKeepsOnePreferencesRecord() throws {
        let container = try AppPersistence.makeContainer(inMemory: true)
        let repository = SwiftDataAppearanceRepository(context: container.mainContext)
        for theme in AppTheme.allCases {
            try repository.save(theme: theme)
            XCTAssertEqual(try repository.theme(), theme)
        }
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<AppAppearanceRecord>()), 1)
    }

    func testUnknownStoredThemeFallsBackWithoutOverwritingFutureValue() throws {
        let container = try AppPersistence.makeContainer(inMemory: true)
        let record = AppAppearanceRecord(theme: .plum)
        record.themeRaw = "future-theme"
        container.mainContext.insert(record)
        try container.mainContext.save()
        XCTAssertEqual(try SwiftDataAppearanceRepository(context: container.mainContext).theme(), .tidewater)
        XCTAssertEqual(record.themeRaw, "future-theme")
    }

    func testExpandedThemesSurviveDiskReopeningWithoutDuplicatingPreferences() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("ExpandedThemes.store")
        for theme: AppTheme in [.indigo, .forest, .coral, .gold] {
            do {
                let container = try AppPersistence.makeContainer(storeURL: url)
                try SwiftDataAppearanceRepository(context: container.mainContext).save(theme: theme)
            }
            let reopened = try AppPersistence.makeContainer(storeURL: url)
            let repository = SwiftDataAppearanceRepository(context: reopened.mainContext)
            XCTAssertEqual(try repository.theme(), theme)
            let records = try reopened.mainContext.fetch(FetchDescriptor<AppAppearanceRecord>())
            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(records.first?.themeRaw, theme.rawValue)
        }
    }

    func testExistingStoredThemeValuesRemainSelectedAfterPaletteExpansion() throws {
        let container = try AppPersistence.makeContainer(inMemory: true)
        let record = AppAppearanceRecord(theme: .tidewater)
        container.mainContext.insert(record)
        let repository = SwiftDataAppearanceRepository(context: container.mainContext)
        // Literal values model preferences saved by the original five-theme app.
        let originalSelections: [(String, AppTheme)] = [
            ("tidewater", .tidewater), ("sapphire", .sapphire), ("plum", .plum),
            ("ember", .ember), ("rose", .rose)
        ]
        for (storedRaw, expected) in originalSelections {
            record.themeRaw = storedRaw
            try container.mainContext.save()
            XCTAssertEqual(try repository.theme(), expected)
            XCTAssertEqual(record.themeRaw, storedRaw)
            XCTAssertFalse(container.mainContext.hasChanges, "Reading an existing preference must not rewrite it")
        }
    }

    func testThemeSurvivesRelaunchAndPreservesCompanionPreferences() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Theme.store")
        let expected = CompanionProfile(selectedAnimal: .otter, companionEnabled: false,
                                        hapticsEnabled: false, onboardingCompleted: true)
        do {
            let container = try AppPersistence.makeContainer(storeURL: url)
            let profiles = SwiftDataCompanionProfileRepository(modelContext: container.mainContext)
            try profiles.save(expected)
            try SwiftDataAppearanceRepository(context: container.mainContext).save(theme: .sapphire)
            XCTAssertEqual(try profiles.profile(), expected)
        }
        let reopened = try AppPersistence.makeContainer(storeURL: url)
        XCTAssertEqual(try SwiftDataAppearanceRepository(context: reopened.mainContext).theme(), .sapphire)
        let profiles = SwiftDataCompanionProfileRepository(modelContext: reopened.mainContext)
        XCTAssertEqual(try profiles.profile(), expected)
        var updated = try profiles.profile()
        updated.selectedAnimal = .fox
        try profiles.save(updated)
        XCTAssertEqual(try SwiftDataAppearanceRepository(context: reopened.mainContext).theme(), .sapphire)
    }

    func testAddingAppearanceModelPreservesPreviousStoreAndDefaultsTheme() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Migration.store")
        // The actual immediately preceding schema, without an appearance entity.
        let schema = Schema([HealthHabitConnectionRecord.self, HabitReminderRecord.self,
            HabitRecord.self, HabitConfigurationSnapshotRecord.self, CompletionRecord.self,
            SkipRecord.self, HabitArchivePeriodRecord.self, AttentionGoalRecord.self,
            AttentionGoalConfigurationSnapshotRecord.self, AttentionUsageEntryRecord.self,
            AttentionCheckInRecord.self, AttentionSessionRecord.self, CompanionProfileRecord.self])
        let expected = CompanionProfile(selectedAnimal: .fox, companionEnabled: false,
                                        hapticsEnabled: false, onboardingCompleted: true)
        var habitID: UUID!
        var completionID: UUID!
        var skipID: UUID!
        let trackedAt = Date()
        do {
            let previous = try ModelContainer(for: schema, configurations: [
                ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
            try SwiftDataCompanionProfileRepository(modelContext: previous.mainContext).save(expected)
            habitID = try SwiftDataHabitRepository(modelContext: previous.mainContext).createHabit(
                HabitDraft(name: "Keep my history", iconName: "book.fill", category: .learning,
                           polarity: .positive, schedule: .daily), at: trackedAt.addingTimeInterval(-2 * 86400)).id
            let habits = SwiftDataHabitRepository(modelContext: previous.mainContext)
            completionID = try habits.recordCompletion(habitID: habitID, at: trackedAt, source: .app, note: "Preserve this note").id
            skipID = try habits.recordSkip(habitID: habitID, on: trackedAt.addingTimeInterval(-86400), reason: .travel).id
        }
        let reopened = try AppPersistence.makeContainer(storeURL: url)
        XCTAssertEqual(try SwiftDataCompanionProfileRepository(modelContext: reopened.mainContext).profile(), expected)
        XCTAssertEqual(try SwiftDataHabitRepository(modelContext: reopened.mainContext).fetchHabit(id: habitID)?.name, "Keep my history")
        let habits = SwiftDataHabitRepository(modelContext: reopened.mainContext)
        let history = DateInterval(start: .distantPast, end: .distantFuture)
        let completions = try habits.completions(for: habitID, in: history)
        XCTAssertEqual(completions.map(\.id), [completionID!])
        XCTAssertEqual(completions.first?.note, "Preserve this note")
        XCTAssertEqual(try habits.skips(for: habitID, in: history).map(\.id), [skipID!])
        XCTAssertEqual(try habits.configurationHistory(for: habitID).count, 1)
        let appearance = SwiftDataAppearanceRepository(context: reopened.mainContext)
        XCTAssertEqual(try appearance.theme(), .tidewater)
        try appearance.save(theme: .rose)
        XCTAssertEqual(try appearance.theme(), .rose)
    }

    func testSelectionPublishesOnlyAfterSuccessfulSave() {
        let repository = TestAppearanceRepository()
        let model = AppThemeViewModel(repository: repository)
        model.load()
        XCTAssertEqual(model.selectedTheme, .tidewater)
        repository.failSave = true
        XCTAssertFalse(model.select(.ember))
        XCTAssertEqual(model.selectedTheme, .tidewater)
        XCTAssertEqual(repository.storedTheme, .tidewater)
        XCTAssertNotNil(model.errorMessage)
        repository.failSave = false
        XCTAssertTrue(model.select(.ember))
        XCTAssertEqual(model.selectedTheme, .ember)
        XCTAssertEqual(repository.storedTheme, .ember)
    }

    func testLoadFailureDoesNotAllowReplacingAnUnreadPreference() {
        let repository = TestAppearanceRepository()
        repository.storedTheme = .plum
        repository.failRead = true
        let model = AppThemeViewModel(repository: repository)
        model.load()
        XCTAssertFalse(model.hasLoaded)
        XCTAssertFalse(model.select(.tidewater))
        XCTAssertEqual(repository.storedTheme, .plum)
        XCTAssertNotNil(model.errorMessage)
    }

    func testAllThemeTextAndFeedbackColorsMeetContrastInLightAndDark() {
        for theme in AppTheme.allCases {
            let palette = AppPalette(theme: theme)
            for style: UIUserInterfaceStyle in [.light, .dark] {
                let traits = UITraitCollection(userInterfaceStyle: style)
                let accent = UIColor(palette.accent).resolvedColor(with: traits)
                for surface in [Color.appBackground, .appSurface, .appSurfaceSecondary] {
                    XCTAssertGreaterThanOrEqual(contrast(accent, UIColor(surface).resolvedColor(with: traits)), 4.5,
                                                "\(theme.title) accent on \(style) surface")
                }
                XCTAssertGreaterThanOrEqual(contrast(accent, UIColor(palette.onAccent).resolvedColor(with: traits)), 4.5,
                                            "\(theme.title) completion control")
                XCTAssertGreaterThanOrEqual(contrast(UIColor(palette.prominentFill).resolvedColor(with: traits),
                                                    UIColor(palette.prominentInk).resolvedColor(with: traits)), 4.5,
                                            "\(theme.title) native prominent button")
                let toastBackground = UIColor(palette.toastBackground).resolvedColor(with: traits)
                XCTAssertGreaterThanOrEqual(contrast(toastBackground, UIColor(palette.toastInk).resolvedColor(with: traits)), 4.5,
                                            "\(theme.title) toast text and Undo")
                XCTAssertGreaterThanOrEqual(contrast(toastBackground, UIColor(palette.toastIcon).resolvedColor(with: traits)), 3,
                                            "\(theme.title) toast symbol")
            }
        }
    }

    func testThemedCanvasesCardsAndHeroMaintainReadableContrast() {
        for theme in AppTheme.allCases {
            let palette = AppPalette(theme: theme)
            for style: UIUserInterfaceStyle in [.light, .dark] {
                let traits = UITraitCollection(userInterfaceStyle: style)
                for surface in [palette.pageTop, palette.atmosphere, palette.pageBottom, palette.surface, palette.surfaceSecondary] {
                    let background = UIColor(surface).resolvedColor(with: traits)
                    for text in [Color.appInk, .appInkSecondary] {
                        XCTAssertGreaterThanOrEqual(contrast(background, UIColor(text).resolvedColor(with: traits)), 4.5,
                            "\(theme.title) reading surface in \(style)")
                    }
                }
                // Hero and ribbons use deep opaque endpoints in both modes.
                // Sampling the ramp also guards against a poor middle blend.
                let first = UIColor(palette.prominentFill).resolvedColor(with: traits)
                let last = UIColor(palette.heroEnd).resolvedColor(with: traits)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                var lr: CGFloat = 0, lg: CGFloat = 0, lb: CGFloat = 0, la: CGFloat = 0
                first.getRed(&r, green: &g, blue: &b, alpha: &a)
                last.getRed(&lr, green: &lg, blue: &lb, alpha: &la)
                for step in 0...10 {
                    let fraction = CGFloat(step) / 10
                    let color = UIColor(red: r + (lr - r) * fraction, green: g + (lg - g) * fraction,
                                        blue: b + (lb - b) * fraction, alpha: 1)
                    XCTAssertGreaterThanOrEqual(contrast(color, .white), 4.5, "\(theme.title) hero ramp")
                }
                let accent = UIColor(palette.accent).resolvedColor(with: traits)
                XCTAssertGreaterThanOrEqual(contrast(accent, UIColor(palette.surface).resolvedColor(with: traits)), 4.5)
            }
        }
    }

    func testHabitIdentitySymbolsRemainVisibleOnTheirTintedTiles() {
        for symbol in ["book.fill", "figure.walk", "leaf.fill", "heart.fill", "drop.fill"] {
            let palette = AppPalette(theme: HabitIconBadge.identityTheme(for: symbol))
            for style: UIUserInterfaceStyle in [.light, .dark] {
                let traits = UITraitCollection(userInterfaceStyle: style)
                let ink = UIColor(palette.accent).resolvedColor(with: traits)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                ink.getRed(&r, green: &g, blue: &b, alpha: &a)
                for base in [palette.surface, Color.appSurface] {
                    let background = UIColor(base).resolvedColor(with: traits)
                    var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
                    background.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
                    let tile = UIColor(red: br * 0.9 + r * 0.1, green: bg * 0.9 + g * 0.1,
                                       blue: bb * 0.9 + b * 0.1, alpha: 1)
                    XCTAssertGreaterThanOrEqual(contrast(ink, tile), 3, "\(symbol) glyph in \(style)")
                }
            }
        }
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func contrast(_ a: UIColor, _ b: UIColor) -> Double {
        let x = luminance(a), y = luminance(b)
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
    private func luminance(_ color: UIColor) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let linear = [red, green, blue].map { value -> Double in
            let value = Double(value)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722
    }
}

@MainActor
private final class TestAppearanceRepository: AppearanceRepository {
    var storedTheme: AppTheme = .tidewater
    var failRead = false
    var failSave = false
    enum Failure: Error { case unavailable }
    func theme() throws -> AppTheme {
        if failRead { throw Failure.unavailable }
        return storedTheme
    }
    func save(theme: AppTheme) throws {
        if failSave { throw Failure.unavailable }
        storedTheme = theme
    }
}
