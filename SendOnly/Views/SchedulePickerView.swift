import SwiftUI

struct SchedulePickerView: View {
    let onSchedule: (Date) -> Void

    @State private var selectedDate = Date().addingTimeInterval(3600) // 1 hour from now
    @State private var selectedPreset: SchedulePreset?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Schedule Send")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Quick presets
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Options")
                    .font(.caption)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(SchedulePreset.allCases, id: \.self) { preset in
                        PresetButton(
                            preset: preset,
                            isSelected: selectedPreset == preset
                        ) {
                            selectedPreset = preset
                            selectedDate = preset.date
                        }
                    }
                }
            }

            Divider()

            // Custom date/time picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom Time")
                    .font(.caption)
                    .foregroundColor(.secondary)

                DatePicker(
                    "Send at",
                    selection: $selectedDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .onChange(of: selectedDate) { _, _ in
                    selectedPreset = nil
                }
            }

            // Selected time display
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.accentColor)
                Text("Will send: \(formattedDate)")
                    .font(.callout)
                Spacer()
            }
            .padding()
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)

            Spacer()

            // Action buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Schedule") {
                    onSchedule(selectedDate)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(selectedDate <= Date())
            }
        }
        .padding()
        #if os(macOS)
        .frame(width: 350, height: 400)
        #endif
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: selectedDate)
    }
}

// MARK: - Schedule Presets

enum SchedulePreset: CaseIterable {
    case laterToday
    case tomorrow
    case mondayMorning
    case nextWeek

    var title: String {
        switch self {
        case .laterToday: return "Later Today"
        case .tomorrow: return "Tomorrow"
        case .mondayMorning: return "Monday Morning"
        case .nextWeek: return "Next Week"
        }
    }

    var subtitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        switch self {
        case .laterToday:
            return formatter.string(from: date)
        case .tomorrow:
            formatter.dateFormat = "E, h:mm a"
            return formatter.string(from: date)
        case .mondayMorning:
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: date)
        case .nextWeek:
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }

    var icon: String {
        switch self {
        case .laterToday: return "clock"
        case .tomorrow: return "sunrise"
        case .mondayMorning: return "calendar"
        case .nextWeek: return "calendar.badge.clock"
        }
    }

    var date: Date {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .laterToday:
            // 3 hours from now, rounded to next hour
            let later = now.addingTimeInterval(3 * 3600)
            let components = calendar.dateComponents([.year, .month, .day, .hour], from: later)
            return calendar.date(from: components)?.addingTimeInterval(3600) ?? later

        case .tomorrow:
            // Tomorrow at 9 AM
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.day! += 1
            components.hour = 9
            components.minute = 0
            return calendar.date(from: components) ?? now.addingTimeInterval(86400)

        case .mondayMorning:
            // Next Monday at 9 AM
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            components.weekday = 2 // Monday
            components.hour = 9
            components.minute = 0
            if let monday = calendar.date(from: components), monday <= now {
                components.weekOfYear! += 1
                return calendar.date(from: components) ?? now.addingTimeInterval(7 * 86400)
            }
            return calendar.date(from: components) ?? now.addingTimeInterval(7 * 86400)

        case .nextWeek:
            // Same day next week at 9 AM
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.day! += 7
            components.hour = 9
            components.minute = 0
            return calendar.date(from: components) ?? now.addingTimeInterval(7 * 86400)
        }
    }
}

// MARK: - Preset Button

struct PresetButton: View {
    let preset: SchedulePreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: preset.icon)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.title)
                        .font(.callout)
                    Text(preset.subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.platformControlBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SchedulePickerView { date in
        print("Scheduled for: \(date)")
    }
}
