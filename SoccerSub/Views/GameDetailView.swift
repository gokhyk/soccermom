import SwiftUI
import SwiftData

struct GameDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let team: Team
    let game: Game

    @State private var availabilityVM: AvailabilityViewModel
    @State private var showEditGame = false
    @State private var showMismatchAlert = false
    @State private var gameStarted = false

    init(game: Game, team: Team) {
        self.game = game
        self.team = team
        _availabilityVM = State(initialValue: AvailabilityViewModel(game: game))
    }

    var body: some View {
        let bvm = Bindable(availabilityVM)

        List {
            Section("Game Info") {
                LabeledContent("Date") {
                    Text(game.dateTime.formatted(
                        .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()
                    ))
                    .foregroundStyle(.secondary)
                }
                if !game.field.isEmpty {
                    LabeledContent("Field", value: game.field)
                }
                if let address = game.address, !address.isEmpty {
                    LabeledContent("Address", value: address)
                }
                LabeledContent("Format") {
                    Text("\(game.playersOnField)v\(game.playersOnField) · \(game.numberOfPeriods) × \(game.periodDurationSeconds / 60) min")
                        .foregroundStyle(.secondary)
                }
            }

            if game.status != .completed {
                Section("Pre-Game Setup") {
                    Picker("Substitutions", selection: bvm.substitutionFrequency) {
                        ForEach(SubstitutionFrequency.allCases, id: \.self) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                    NavigationLink {
                        AvailabilityView(viewModel: availabilityVM)
                    } label: {
                        LabeledContent("Attendance") {
                            Text("\(availabilityVM.availableCount) available")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    if game.status == .scheduled {
                        Button(action: handleStartTapped) {
                            Label("Start Game", systemImage: "whistle.fill")
                                .frame(maxWidth: .infinity)
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!availabilityVM.canStart)
                        .listRowBackground(Color.clear)
                        .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
                    } else {
                        // .inProgress
                        Button {
                            gameStarted = true
                        } label: {
                            Label("Continue Game", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .listRowBackground(Color.clear)
                        .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
                    }
                }
            } else {
                Section {
                    LabeledContent("Status", value: "Completed")
                }
            }
        }
        .navigationTitle("vs \(game.opponent)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if game.status == .scheduled {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { showEditGame = true }
                }
            }
        }
        .sheet(isPresented: $showEditGame) {
            GameEditView(editing: game, team: team)
        }
        .alert("Wrong Game?", isPresented: $showMismatchAlert) {
            Button("Start Anyway", role: .destructive) { doStart() }
            Button("Go Back", role: .cancel) { }
        } message: {
            Text(
                "This game is scheduled for " +
                game.dateTime.formatted(.dateTime.weekday(.wide).month().day().hour().minute()) +
                ". Start it now anyway?"
            )
        }
        .onChange(of: gameStarted) { old, new in
            // LiveGameView was dismissed (gameStarted went true→false) and the game finished
            if old == true, new == false, game.status == .completed {
                dismiss()
            }
        }
        .navigationDestination(isPresented: $gameStarted) {
            LiveGameView(game: game, context: modelContext)
        }
    }

    private func handleStartTapped() {
        if availabilityVM.isMismatch {
            showMismatchAlert = true
        } else {
            doStart()
        }
    }

    private func doStart() {
        availabilityVM.startGame(context: modelContext)
        gameStarted = true
    }
}
