import SwiftUI
import SwiftData

struct GameManagementView: View {
    @Environment(\.modelContext) private var modelContext
    let team: Team

    @State private var showingAddGame = false
    @State private var gameToEdit: Game?

    private var sortedGames: [Game] {
        GameSorting.sorted(team.games)
    }

    var body: some View {
        List {
            ForEach(sortedGames) { game in
                GameRow(game: game)
                    .contentShape(Rectangle())
                    .onTapGesture { gameToEdit = game }
                    // TODO (Prompt 06): replace tap with navigation to AvailabilityView
            }
            .onDelete(perform: deleteGames)
        }
        .navigationTitle("Games — \(team.name)")
        .overlay {
            if sortedGames.isEmpty {
                ContentUnavailableView(
                    "No Games Yet",
                    systemImage: "calendar.badge.plus",
                    description: Text("Tap + to schedule the first game.")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Game", systemImage: "calendar.badge.plus") {
                    showingAddGame = true
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingAddGame) {
            GameEditView(team: team)
        }
        .sheet(item: $gameToEdit) { game in
            GameEditView(editing: game, team: team)
        }
    }

    private func deleteGames(at offsets: IndexSet) {
        let games = sortedGames
        offsets.forEach { modelContext.delete(games[$0]) }
        try? modelContext.save()
    }
}

// MARK: – Row

private struct GameRow: View {
    let game: Game

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("vs \(game.opponent)")
                    .font(.headline)
                HStack(spacing: 6) {
                    Text(game.dateTime.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !game.field.isEmpty {
                        Text("· \(game.field)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            StatusBadge(status: game.status)
        }
        .padding(.vertical, 2)
    }
}

private struct StatusBadge: View {
    let status: GameStatus

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var label: String {
        switch status {
        case .scheduled:  return "Upcoming"
        case .inProgress: return "Live"
        case .completed:  return "Done"
        }
    }

    private var color: Color {
        switch status {
        case .scheduled:  return .blue
        case .inProgress: return .green
        case .completed:  return .secondary
        }
    }
}
