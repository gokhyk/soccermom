import SwiftUI

/// Placeholder screen navigated to after starting a game.
/// The real implementation is built in Prompt 08.
struct LiveGamePlaceholderView: View {
    let game: Game

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "soccerball")
                .font(.system(size: 72))
                .foregroundStyle(.green)

            Text("Game in Progress")
                .font(.largeTitle.bold())

            Text("vs \(game.opponent)")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Live game view coming in Prompt 08")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
        .padding()
        .navigationTitle("Live Game")
        .navigationBarTitleDisplayMode(.inline)
    }
}
