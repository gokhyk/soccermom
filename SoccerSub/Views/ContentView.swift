import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Team.name) private var teams: [Team]

    @State private var showAddTeam = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(teams) { team in
                    NavigationLink(destination: TeamDetailView(team: team)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(team.name)
                                .font(.headline)
                            if !team.leagueName.isEmpty {
                                Text(team.leagueName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { deleteTeam(team) } label: {
                            Label("Delete", systemImage: "trash")
                        }
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
        }
    }

    private func deleteTeam(_ team: Team) {
        modelContext.delete(team)
        try? modelContext.save()
    }
}
