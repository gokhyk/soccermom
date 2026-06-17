import SwiftUI
import SwiftData

struct RosterView: View {
    @Environment(\.modelContext) private var modelContext
    let team: Team

    @State private var showingAddPlayer = false
    @State private var playerToEdit: Player?

    private var sortedPlayers: [Player] {
        team.players.sorted { $0.jerseyNumber < $1.jerseyNumber }
    }

    var body: some View {
        List {
            ForEach(sortedPlayers) { player in
                PlayerRow(player: player)
                    .contentShape(Rectangle())
                    .onTapGesture { playerToEdit = player }
            }
            .onDelete(perform: deletePlayers)
        }
        .navigationTitle("Roster — \(team.name)")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Player", systemImage: "person.badge.plus") {
                    showingAddPlayer = true
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingAddPlayer) {
            PlayerEditView(team: team)
        }
        .sheet(item: $playerToEdit) { player in
            PlayerEditView(editing: player, team: team)
        }
    }

    private func deletePlayers(at offsets: IndexSet) {
        let players = sortedPlayers
        offsets.forEach { modelContext.delete(players[$0]) }
        try? modelContext.save()
    }
}

// MARK: - Row

private struct PlayerRow: View {
    let player: Player

    var body: some View {
        HStack {
            Text("#\(player.jerseyNumber)")
                .font(.headline.monospacedDigit())
                .frame(width: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.body)
                Text(positionSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(TimeFormatting.format(player.seasonPlayedSeconds))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var positionSummary: String {
        let tags: [(Bool, String)] = [
            (player.canPlayGoalkeeper,  "GK"),
            (player.canPlayDefender,    "DEF"),
            (player.canPlayMidfielder,  "MID"),
            (player.canPlayAttacker,    "ATT"),
        ]
        let active = tags.compactMap { $0.0 ? $0.1 : nil }
        return active.isEmpty ? "No positions" : active.joined(separator: " · ")
    }
}
