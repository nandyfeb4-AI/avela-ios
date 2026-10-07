import SwiftUI

/// Reflection is a private journal, separate from the calculated weekly review.
struct ReflectionView: View {
    @State private var viewModel: ReflectionViewModel
    @State private var showingEditor = false
    @State private var showingDelete = false

    init(repository: ReflectionRepository, habits: HabitRepository? = nil, calendar: Calendar = .autoupdatingCurrent, weekContaining date: Date = Date()) {
        _viewModel = State(initialValue: ReflectionViewModel(repository: repository, habits: habits, calendar: calendar, now: date))
    }

    init(viewModel: ReflectionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            Section {
                Text(viewModel.weekLabel).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    .accessibilityIdentifier("reflection.week")
                Text("A little space to reflect").font(.title2.weight(.semibold))
                Text("Private notes for your week. Progress stays based on your recorded check-ins.")
                    .foregroundStyle(.secondary)
            }
            if viewModel.hasLoaded {
                Section {
                    if let error = viewModel.progressError {
                        Text(error).foregroundStyle(.secondary)
                        Button("Reload Progress") { viewModel.load() }
                    } else if viewModel.habitResults.isEmpty {
                        Text("No finished habit commitments to review this week yet.")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("reflection.progressEmpty")
                    } else {
                        ForEach(viewModel.habitResults, id: \.habitID) { result in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.habitName).font(.headline)
                                Text("\(result.successfulUnits) of \(result.scheduledUnits) commitments successful")
                                if result.isArchived { Text("Archived").font(.caption) }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("reflection.progress.\(result.habitID)")
                        }
                    }
                } header: {
                    Text("Recorded This Week")
                } footer: {
                    Text(viewModel.isCurrentWeek
                         ? "Week in progress. Unfinished commitments, skips and paused time are excluded. A commitment can mean a scheduled day or a flexible week. Your notes aren't analyzed."
                         : "From recorded habit history. Skips and paused time are excluded. A commitment can mean a scheduled day or a flexible week. Your notes aren't analyzed.")
                }
                if let reflection = viewModel.reflection {
                    if !reflection.whatHelped.isEmpty {
                        Section("What Helped?") {
                            Text(reflection.whatHelped).textSelection(.enabled)
                                .accessibilityIdentifier("reflection.savedHelped")
                        }
                    }
                    if !reflection.whatGotInTheWay.isEmpty {
                        Section("What Got in the Way?") {
                            Text(reflection.whatGotInTheWay).textSelection(.enabled)
                                .accessibilityIdentifier("reflection.savedObstacle")
                        }
                    }
                    Section {
                        Button { edit() } label: {
                            Text("Edit Reflection").frame(minHeight: 44)
                        }.accessibilityIdentifier("reflection.edit")
                        Button(role: .destructive) { showingDelete = true } label: {
                            Text("Delete Reflection").frame(minHeight: 44)
                        }.accessibilityIdentifier("reflection.delete")
                    } footer: { privacyNote }
                } else {
                    Section {
                        Text("Room to Reflect").font(.headline).accessibilityAddTraits(.isHeader)
                        Text("What made things easier? What got in the way? Either answer is optional.")
                            .foregroundStyle(.secondary)
                        Button { edit() } label: {
                            Text("Write a Reflection").frame(minHeight: 44)
                        }.accessibilityIdentifier("reflection.write")
                    } footer: { privacyNote }
                }
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.secondary)
                        Button("Try Again") { viewModel.load() }
                    }
                }
            } else {
                Section {
                    if let error = viewModel.errorMessage { Text(error).foregroundStyle(.secondary) }
                    Button("Try Again") { viewModel.load() }
                        .accessibilityIdentifier("reflection.retry")
                }
            }
        }
        .appThemeCanvas()
        .navigationTitle("Weekly Reflection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { viewModel.selectWeek(offset: -1) } label: {
                    Image(systemName: "chevron.backward").frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Previous reflection week")
                .accessibilityIdentifier("reflection.previousWeek")
                Button { viewModel.selectWeek(offset: 1) } label: {
                    Image(systemName: "chevron.forward").frame(minWidth: 44, minHeight: 44)
                }
                .disabled(!viewModel.canMoveForward())
                .accessibilityLabel("Next reflection week")
                .accessibilityIdentifier("reflection.nextWeek")
            }
        }
        .task { viewModel.load() }
        .sheet(isPresented: $showingEditor, onDismiss: { viewModel.cancelEditing() }) {
            ReflectionEditorView(viewModel: viewModel)
        }
        .alert("Delete this week's reflection?", isPresented: $showingDelete) {
            Button("Delete", role: .destructive) { viewModel.delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes only your note. Habits, check-ins and weekly results stay unchanged.")
        }
    }

    private var privacyNote: some View {
        Text("Optional, private notes stored on this device. Apple device backups may include them. Avela doesn't send them to a server.")
    }
    private func edit() { viewModel.beginEditing(); showingEditor = true }
}

private struct ReflectionEditorView: View {
    @Bindable var viewModel: ReflectionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(viewModel.weekLabel).font(.headline)
                    Text("Write what feels useful. One answer is enough, and you can leave either prompt blank.")
                        .foregroundStyle(.secondary)
                }
                Section("What Helped?") {
                    TextEditor(text: $viewModel.draft.whatHelped)
                        .frame(minHeight: 120)
                        .accessibilityLabel("What helped this week?")
                        .accessibilityIdentifier("reflection.helpedEditor")
                    count(viewModel.draft.whatHelped)
                }
                Section("What Got in the Way?") {
                    TextEditor(text: $viewModel.draft.whatGotInTheWay)
                        .frame(minHeight: 120)
                        .accessibilityLabel("What got in the way this week?")
                        .accessibilityIdentifier("reflection.obstacleEditor")
                    count(viewModel.draft.whatGotInTheWay)
                }
                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(.secondary).accessibilityIdentifier("reflection.error") }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .appThemeCanvas()
            .navigationTitle("Your Reflection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.cancelEditing(); dismiss() }
                        .accessibilityIdentifier("reflection.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { if viewModel.save() { dismiss() } }
                        .disabled(!viewModel.draft.isValid || !viewModel.hasLoaded)
                        .accessibilityIdentifier("reflection.save")
                }
            }
        }
    }

    private func count(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(text.count) of \(ReflectionDraft.characterLimit) characters")
            if text.count > ReflectionDraft.characterLimit {
                Text("Shorten this answer to save your reflection.")
            }
        }
        .font(.footnote).foregroundStyle(.secondary)
    }
}
