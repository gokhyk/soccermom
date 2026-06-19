import SwiftUI
import SwiftData

struct TeamSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TeamSetupViewModel
    @State private var showDeleteConfirmation = false

    init(editing team: Team? = nil) {
        _viewModel = State(initialValue: TeamSetupViewModel(editing: team))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Team Info") {
                    TextField("Team Name", text: $viewModel.name)
                    TextField("League Name", text: $viewModel.leagueName)

                    Picker("Age Group", selection: Binding(
                        get: { viewModel.ageGroup },
                        set: { viewModel.selectAgeGroup($0) }
                    )) {
                        Text("Select age group…").tag("")
                        ForEach(AgeGroupDefaults.allAgeGroups, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                }

                if viewModel.isEditingExisting {
                    Section {
                        Button("Delete Team", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }
                }

                Section("Game Defaults") {
                    Stepper(
                        "Players on field: \(viewModel.playersOnField)",
                        value: $viewModel.playersOnField,
                        in: 1...15
                    )

                    Stepper(
                        "Periods: \(viewModel.numberOfPeriods)",
                        value: $viewModel.numberOfPeriods,
                        in: 1...8
                    )

                    Stepper(
                        "Period duration: \(viewModel.periodDurationSeconds / 60) min",
                        value: Binding(
                            get: { viewModel.periodDurationSeconds / 60 },
                            set: { viewModel.periodDurationSeconds = $0 * 60 }
                        ),
                        in: 1...90
                    )

                    Stepper(
                        "Break duration: \(viewModel.breakDurationSeconds / 60) min",
                        value: Binding(
                            get: { viewModel.breakDurationSeconds / 60 },
                            set: { viewModel.breakDurationSeconds = $0 * 60 }
                        ),
                        in: 1...30
                    )
                }
            }
            .navigationTitle(viewModel.isEditingExisting ? "Edit Team" : "New Team")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.save(to: modelContext)
                        dismiss()
                    }
                    .disabled(!viewModel.isValid)
                }
            }
            .alert("Delete Team?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    viewModel.deleteTeam(from: modelContext)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete the team along with all its players and games. This cannot be undone.")
            }
        }
    }
}
