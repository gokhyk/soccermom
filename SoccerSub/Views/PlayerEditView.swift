import SwiftUI
import SwiftData

struct PlayerEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: PlayerEditViewModel

    init(editing player: Player? = nil, team: Team) {
        _viewModel = State(initialValue: PlayerEditViewModel(editing: player, inTeam: team))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Player Info") {
                    TextField("Name", text: $viewModel.name)

                    HStack {
                        Text("Jersey #")
                        Spacer()
                        TextField("e.g. 7", text: $viewModel.jerseyNumberText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                Section("Eligible Positions") {
                    Toggle("Goalkeeper",  isOn: $viewModel.canPlayGoalkeeper)
                    Toggle("Defender",    isOn: $viewModel.canPlayDefender)
                    Toggle("Midfielder",  isOn: $viewModel.canPlayMidfielder)
                    Toggle("Attacker",    isOn: $viewModel.canPlayAttacker)
                }

                if viewModel.isEditingExisting {
                    Section("Season Stats") {
                        LabeledContent("Time played", value: viewModel.seasonPlayedDisplay)
                    }
                }

                if let summary = viewModel.validationSummary {
                    Section {
                        Text(summary)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(viewModel.isEditingExisting ? "Edit Player" : "New Player")
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
