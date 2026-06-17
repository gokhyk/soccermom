import SwiftUI

struct ThemeManagementView: View {
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        List(AppTheme.allThemes) { theme in
            ThemeRow(
                theme: theme,
                isSelected: theme.id == themeManager.current.id
            ) {
                themeManager.select(theme)
            }
        }
        .navigationTitle("Color Theme")
    }
}

// MARK: – Row

private struct ThemeRow: View {
    let theme: AppTheme
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ThemeColorSwatch(theme: theme)
                    .frame(width: 88, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isSelected ? theme.accent : Color.clear, lineWidth: 2)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(theme.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    // Marker color dots — a quick visual indicator
                    HStack(spacing: 6) {
                        MarkerDot(color: theme.onFieldMarker, label: "On")
                        MarkerDot(color: theme.benchMarker,   label: "Bench")
                        MarkerDot(color: theme.absentMarker,  label: "Absent")
                        MarkerDot(color: theme.accent,        label: "Accent")
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: – Field color swatch

private struct ThemeColorSwatch: View {
    let theme: AppTheme

    var body: some View {
        ZStack(alignment: .bottom) {
            // Alternating stripe mini-field
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { i in
                    (i.isMultiple(of: 2) ? theme.fieldPrimary : theme.fieldSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            // Accent bar at the bottom
            theme.accent
                .frame(maxWidth: .infinity)
                .frame(height: 8)
        }
    }
}

// MARK: – Marker dot

private struct MarkerDot: View {
    let color: Color
    let label: String

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
            .accessibilityLabel(label)
    }
}
