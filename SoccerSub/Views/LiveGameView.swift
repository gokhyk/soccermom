import SwiftUI
import SwiftData

struct LiveGameView: View {
    let game: Game
    @State private var viewModel: LiveGameViewModel
    @State private var showPositionPicker = false
    @State private var pendingBenchAppearance: PlayerGameAppearance? = nil

    init(game: Game, context: ModelContext) {
        self.game = game
        _viewModel = State(initialValue: LiveGameViewModel(game: game, context: context))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            fieldDiagram
                .frame(maxHeight: 320)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            controls
            Divider()
            benchAbsentList
        }
        .navigationTitle("vs \(game.opponent)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.showSubstitutionOverlay) {
            SubstitutionOverlayView(viewModel: viewModel)
        }
        .alert(
            "Period \(viewModel.currentPeriod) Over",
            isPresented: $viewModel.isPeriodEnded
        ) {
            if viewModel.currentPeriod < game.numberOfPeriods {
                Button("Start Period \(viewModel.currentPeriod + 1)") {
                    viewModel.advancePeriod()
                }
            } else {
                Button("End Game", role: .destructive) {
                    viewModel.advancePeriod()
                }
            }
            Button("Stay", role: .cancel) { }
        } message: {
            Text("The period clock has reached \(game.periodDurationSeconds / 60) minutes.")
        }
        .alert("Game Over", isPresented: $viewModel.isGameOver) {
            Button("OK") { }
        } message: {
            Text("All periods complete. Game marked as done.")
        }
        .confirmationDialog(
            "Assign position",
            isPresented: $showPositionPicker,
            titleVisibility: .visible
        ) {
            if let app = pendingBenchAppearance {
                ForEach(positionsFor(app), id: \.self) { pos in
                    Button(pos.rawValue.capitalized) {
                        viewModel.assignToField(app, position: pos)
                        pendingBenchAppearance = nil
                    }
                }
                Button("Cancel", role: .cancel) { pendingBenchAppearance = nil }
            }
        }
    }

    // MARK: – Top bar

    private var topBar: some View {
        HStack {
            Text("Period \(viewModel.currentPeriod)/\(game.numberOfPeriods)")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(timeDisplay)
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .foregroundStyle(viewModel.isRunning ? .primary : .secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var timeDisplay: String {
        let s = viewModel.elapsedPeriodSeconds
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    // MARK: – Field diagram

    private var fieldDiagram: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.gradient)
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.4), lineWidth: 1)

            // Center line
            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(height: 1)

            VStack(spacing: 0) {
                fieldRow(for: .attacker)
                Spacer(minLength: 4)
                fieldRow(for: .midfielder)
                Spacer(minLength: 4)
                fieldRow(for: .defender)
                Spacer(minLength: 4)
                fieldRow(for: .goalkeeper)
            }
            .padding(12)
        }
    }

    private func fieldRow(for position: Position) -> some View {
        let apps = viewModel.onFieldAppearances.filter { $0.positionAssigned == position }
        return HStack(spacing: 8) {
            ForEach(apps) { app in
                PlayerTokenView(appearance: app)
                    .onTapGesture { viewModel.removeFromField(app) }
            }
        }
    }

    // MARK: – Controls

    private var controls: some View {
        Group {
            if viewModel.isGameOver {
                Text("Game Complete")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else if viewModel.isPeriodEnded {
                EmptyView()  // handled by alert
            } else if viewModel.isRunning {
                Button(role: .destructive, action: viewModel.stopClock) {
                    Label("Pause Clock", systemImage: "pause.circle.fill")
                        .font(.headline)
                }
                .padding(.vertical, 12)
            } else {
                Button(action: viewModel.blowWhistle) {
                    Label("Whistle — Start Period \(viewModel.currentPeriod)", systemImage: "whistle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canBlowWhistle)
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: – Bench / Absent list

    private var benchAbsentList: some View {
        List {
            if !viewModel.benchAppearances.isEmpty {
                Section("Bench (\(viewModel.benchAppearances.count))") {
                    ForEach(viewModel.benchAppearances) { app in
                        BenchRowView(appearance: app)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                pendingBenchAppearance = app
                                showPositionPicker = true
                            }
                    }
                }
            }
            if !viewModel.absentAppearances.isEmpty {
                Section("Absent") {
                    ForEach(viewModel.absentAppearances) { app in
                        BenchRowView(appearance: app)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: – Helpers

    private func positionsFor(_ app: PlayerGameAppearance) -> [Position] {
        guard let player = app.player else { return Position.allCases }
        return Position.allCases.filter { player.eligiblePositions.contains($0) }
    }
}

// MARK: – Player token on field

private struct PlayerTokenView: View {
    let appearance: PlayerGameAppearance

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.9))
                    .frame(width: 38, height: 38)
                Text("#\(appearance.player?.jerseyNumber ?? 0)")
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
            }
            Text(firstName)
                .font(.system(size: 9))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }

    private var firstName: String {
        appearance.player?.name.components(separatedBy: " ").first ?? ""
    }
}

// MARK: – Bench / absent row

private struct BenchRowView: View {
    let appearance: PlayerGameAppearance

    var body: some View {
        HStack {
            Text("#\(appearance.player?.jerseyNumber ?? 0)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)
            Text(appearance.player?.name ?? "")
            Spacer()
            Text(TimeFormatting.format(appearance.secondsPlayed))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: – Substitution overlay sheet

private struct SubstitutionOverlayView: View {
    @Bindable var viewModel: LiveGameViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Recommended Substitutions") {
                    if viewModel.pendingSubstitutions.isEmpty {
                        Text("No substitutions needed right now.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.pendingSubstitutions.indices, id: \.self) { i in
                            let pair = viewModel.pendingSubstitutions[i]
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Off: \(playerName(id: pair.playerOut.id))")
                                        .font(.subheadline)
                                    Text("\(TimeFormatting.format(pair.playerOut.secondsPlayed)) played")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.left.arrow.right")
                                    .foregroundStyle(.blue)
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("On: \(playerName(id: pair.playerIn.id))")
                                        .font(.subheadline)
                                    Text("\(TimeFormatting.format(pair.playerIn.secondsPlayed)) played")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sub Suggestion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { viewModel.dismissSubstitutionOverlay() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sub Complete") {
                        viewModel.applySubstitutions()
                    }
                    .disabled(viewModel.pendingSubstitutions.isEmpty)
                }
            }
        }
    }

    private func playerName(id: UUID) -> String {
        viewModel.game.appearances
            .first(where: { $0.player?.id == id })?
            .player?.name ?? "?"
    }
}
