import SwiftUI
import SwiftData

struct TeamDetailView: View {
    let team: Team

    @State private var showEditTeam = false

    var body: some View {
        List {
            Section {
                NavigationLink("Roster") {
                    RosterView(team: team)
                }
                NavigationLink("Games") {
                    GameManagementView(team: team)
                }
            }

            if !team.leagueName.isEmpty || !team.ageGroup.isEmpty {
                Section("Details") {
                    if !team.leagueName.isEmpty {
                        LabeledContent("League", value: team.leagueName)
                    }
                    if !team.ageGroup.isEmpty {
                        LabeledContent("Age Group", value: team.ageGroup)
                    }
                }
            }
        }
        .navigationTitle(team.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEditTeam = true }
            }
        }
        .sheet(isPresented: $showEditTeam) {
            TeamSetupView(editing: team)
        }
    }
}
