import SwiftUI
import SwiftData

struct GameEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: GameEditViewModel

    init(editing game: Game? = nil, team: Team) {
        _viewModel = State(initialValue: GameEditViewModel(editing: game, team: team))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Game Details") {
                    TextField("Opponent", text: $viewModel.opponent)

                    TextField("Field / Venue", text: $viewModel.field)

                    TextField("Address (optional)", text: $viewModel.address)
                        .keyboardType(.default)

                    DatePicker(
                        "Date & Time",
                        selection: $viewModel.dateTime,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                }

                Section("Game Rules") {
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
            .navigationTitle(viewModel.isEditingExisting ? "Edit Game" : "New Game")
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
        }
    }
}
