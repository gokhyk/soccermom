import SwiftUI
import SwiftData

struct AvailabilityView: View {
    @Bindable var viewModel: AvailabilityViewModel

    var body: some View {
        List {
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
        .navigationTitle("Attendance")
        .navigationBarTitleDisplayMode(.inline)
    }
}
