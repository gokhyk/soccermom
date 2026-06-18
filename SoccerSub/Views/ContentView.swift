import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Team.name) private var teams: [Team]

    @State private var showAddTeam = false
    @State private var teamToEdit: Team?

    var body: some View {
        NavigationStack {
            List {
                ForEach(teams) { team in
                    Section(team.name) {
                        NavigationLink("Roster") {
                            RosterView(team: team)
                        }
                        NavigationLink("Games") {
                            GameManagementView(team: team)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { deleteTeam(team) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button { teamToEdit = team } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle("SoccerSub")
            .overlay {
                if teams.isEmpty {
                    ContentUnavailableView(
                        "No Teams Yet",
                        systemImage: "figure.soccer",
                        description: Text("Tap + to create your first team.")
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Team", systemImage: "plus") {
                        showAddTeam = true
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        ThemeManagementView()
                    } label: {
                        Image(systemName: "paintpalette")
                    }
                }
            }
            .sheet(isPresented: $showAddTeam) {
                TeamSetupView()
            }
            .sheet(item: $teamToEdit) { team in
                TeamSetupView(editing: team)
            }
        }
    }

    private func deleteTeam(_ team: Team) {
        modelContext.delete(team)
        try? modelContext.save()
    }
}
