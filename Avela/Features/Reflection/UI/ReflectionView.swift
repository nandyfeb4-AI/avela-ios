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
    @State private var dictationPrompt: ReflectionDictationPrompt?

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
                    dictateButton(for: .helped)
                    count(viewModel.draft.whatHelped)
                }
                Section("What Got in the Way?") {
                    TextEditor(text: $viewModel.draft.whatGotInTheWay)
                        .frame(minHeight: 120)
                        .accessibilityLabel("What got in the way this week?")
                        .accessibilityIdentifier("reflection.obstacleEditor")
                    dictateButton(for: .obstacle)
                    count(viewModel.draft.whatGotInTheWay)
                }
                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(.secondary).accessibilityIdentifier("reflection.error") }
                }
            }
            .sheet(item: $dictationPrompt) { prompt in
                ReflectionDictationView(prompt: prompt.title) { text in
                    switch prompt {
                    case .helped:
                        viewModel.draft.whatHelped = ReflectionDictationModel.appended(text, to: viewModel.draft.whatHelped)
                    case .obstacle:
                        viewModel.draft.whatGotInTheWay = ReflectionDictationModel.appended(text, to: viewModel.draft.whatGotInTheWay)
                    }
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

    private func dictateButton(for prompt: ReflectionDictationPrompt) -> some View {
        Button { dictationPrompt = prompt } label: {
            Label("Dictate", systemImage: "mic")
                .frame(minHeight: 44)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Dictate \(prompt.title.lowercased())")
        .accessibilityIdentifier("reflection.dictate.\(prompt.rawValue)")
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

private enum ReflectionDictationPrompt: String, Identifiable {
    case helped, obstacle
    var id: String { rawValue }
    var title: String { self == .helped ? "What Helped?" : "What Got in the Way?" }
}

private struct ReflectionDictationView: View {
    let prompt: String
    let onInsert: (String) -> Void
    @State private var model = ReflectionDictationModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(prompt, systemImage: "mic").font(.headline)
                    Text("Speak a short reflection, then review the text. Audio stays on this device and isn't saved. Nothing is added until you confirm.")
                        .foregroundStyle(.secondary)
                    Text("On-device recognition must be available for your device and language. Each recording lasts up to 55 seconds.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    if model.phase == .listening {
                        Label("Listening…", systemImage: "mic.fill")
                            .accessibilityIdentifier("reflection.dictation.listening")
                        Button("Stop Recording", systemImage: "stop.circle.fill") { model.stop() }
                            .accessibilityIdentifier("reflection.dictation.stop")
                    } else {
                        Button(model.transcript.isEmpty ? "Start Dictation" : "Record Again", systemImage: "mic") {
                            Task { await model.start() }
                        }
                        .disabled(model.phase == .authorizing)
                        .accessibilityIdentifier("reflection.dictation.start")
                        if model.phase == .authorizing { Text("Waiting for permission…") }
                    }
                    if let message = model.message {
                        Text(message).foregroundStyle(.secondary)
                            .accessibilityIdentifier("reflection.dictation.message")
                    }
                }
                Section("Review Your Words") {
                    TextEditor(text: $model.transcript)
                        .frame(minHeight: 160)
                        .disabled(model.phase == .listening || model.phase == .authorizing)
                        .accessibilityLabel("Dictated reflection text")
                        .accessibilityIdentifier("reflection.dictation.transcript")
                    Text("You can edit this text. Adding it appends to your answer; save the reflection separately.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .appThemeCanvas()
            .navigationTitle("Dictate Reflection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { model.discard(); dismiss() }
                        .accessibilityIdentifier("reflection.dictation.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Text") {
                        model.stop()
                        onInsert(model.transcript)
                        dismiss()
                    }
                    .disabled(!model.canInsert)
                    .accessibilityIdentifier("reflection.dictation.insert")
                }
            }
        }
        .onDisappear { model.discard() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || (phase != .active && model.phase == .listening) { model.stop() }
        }
    }
}
