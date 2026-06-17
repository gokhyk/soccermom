import SwiftUI
import SwiftData

struct AvailabilityView: View {
    @Environment(\.modelContext) private var modelContext

    let game: Game
    @State private var viewModel: AvailabilityViewModel
    @State private var showMismatchAlert = false
    @State private var gameStarted = false

    init(game: Game) {
        self.game = game
        _viewModel = State(initialValue: AvailabilityViewModel(game: game))
    }

    var body: some View {
        List {
            Section {
                Button(action: handleStartTapped) {
                    Label("Start Game", systemImage: "whistle.fill")
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canStart)
                .listRowBackground(Color.clear)
                .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))

                Picker("Substitution frequency", selection: $viewModel.substitutionFrequency) {
                    ForEach(SubstitutionFrequency.allCases, id: \.self) { freq in
                        Text(freq.displayName).tag(freq)
                    }
                }
            }

            Section("Roster (\(viewModel.availableCount) available)") {
                ForEach(viewModel.rows.indices, id: \.self) { i in
                    Toggle(isOn: Binding(
                        get: { viewModel.rows[i].status == .available },
                        set: { viewModel.rows[i].status = $0 ? .available : .absent }
                    )) {
                        HStack(spacing: 8) {
                            Text("#\(viewModel.rows[i].player.jerseyNumber)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 32, alignment: .leading)
                            Text(viewModel.rows[i].player.name)
                        }
                    }
                }
            }
        }
        .navigationTitle("vs \(game.opponent)")
        .navigationBarTitleDisplayMode(.inline)
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
        .navigationDestination(isPresented: $gameStarted) {
            LiveGameView(game: game, context: modelContext)
        }
    }

    private func handleStartTapped() {
        if viewModel.isMismatch {
            showMismatchAlert = true
        } else {
            doStart()
        }
    }

    private func doStart() {
        viewModel.startGame(context: modelContext)
        gameStarted = true
    }
}
