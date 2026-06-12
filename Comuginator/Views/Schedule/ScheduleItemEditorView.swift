import SwiftUI

struct ScheduleItemEditorView: View {
    let card: AacCardDto?
    let item: ScheduleItemDto?      // nil → creating
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var isDateMode = false
    @State private var date = Date()
    @State private var weekdaysSelected: Set<Int> = []   // Mon=1 … Sun=7
    @State private var time = Date()
    @State private var forceShowIds: Set<String> = []
    @State private var forceHideIds: Set<String> = []
    @State private var nodes: [ChildHomeNodeDto] = []
    @State private var isSaving = false
    @State private var statusText = ""

    private var isEditing: Bool { item != nil }
    private let weekdayLabels = [1: "Mon", 2: "Tue", 3: "Wed", 4: "Thu", 5: "Fri", 6: "Sat", 7: "Sun"]

    var body: some View {
        NavigationStack {
            Form {
                // Card preview
                if let card {
                    Section {
                        HStack(spacing: 12) {
                            AuthImageView(urlString: card.imageUrl)
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            Text(card.label).font(.headline)
                        }
                    }
                }

                // Name
                Section("Name (optional)") {
                    TextField("Defaults to the card label", text: $name)
                }

                // Mode
                Section("When") {
                    Picker("Repeat", selection: $isDateMode) {
                        Text("Weekly").tag(false)
                        Text("Exact date").tag(true)
                    }
                    .pickerStyle(.segmented)

                    if isDateMode {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                    } else {
                        // Weekday toggles
                        HStack(spacing: 6) {
                            ForEach(1...7, id: \.self) { day in
                                let isOn = weekdaysSelected.contains(day)
                                Button {
                                    if isOn { weekdaysSelected.remove(day) }
                                    else { weekdaysSelected.insert(day) }
                                } label: {
                                    Text(weekdayLabels[day] ?? "?")
                                        .font(.caption2.weight(.medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(isOn ? Color.blue : Color.secondary.opacity(0.12),
                                                    in: RoundedRectangle(cornerRadius: 8))
                                        .foregroundStyle(isOn ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                }

                // Child home node visibility overrides
                if !nodes.isEmpty {
                    Section("Force Show Tiles") {
                        nodeChecklist(selection: $forceShowIds)
                    }
                    Section("Force Hide Tiles") {
                        nodeChecklist(selection: $forceHideIds)
                    }
                }

                if !statusText.isEmpty {
                    Section { Text(statusText).font(.footnote).foregroundStyle(.red) }
                }
            }
            .navigationTitle(isEditing ? "Edit Schedule" : "New Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss(); onDone() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(isSaving)
                }
            }
            .disabled(isSaving)
            .overlay { if isSaving { ProgressView() } }
        }
        .task {
            populate()
            await loadNodes()
        }
    }

    // MARK: - Node checklist

    @ViewBuilder
    private func nodeChecklist(selection: Binding<Set<String>>) -> some View {
        ForEach(nodes) { node in
            let label = node.labelOverride ?? node.item?.label ?? node.id
            let isOn = selection.wrappedValue.contains(node.id)
            Button {
                if isOn { selection.wrappedValue.remove(node.id) }
                else { selection.wrappedValue.insert(node.id) }
            } label: {
                HStack {
                    Image(systemName: isOn ? "checkmark.square.fill" : "square")
                        .foregroundStyle(isOn ? .blue : .secondary)
                    Text(label).foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Populate / load

    private func populate() {
        guard let item else { return }
        name = item.name ?? ""
        isDateMode = item.mode == "DATE"
        weekdaysSelected = Set(item.weekdays)
        forceShowIds = Set(item.forceShowChildHomeNodeIds)
        forceHideIds = Set(item.forceHideChildHomeNodeIds)

        if let dateStr = item.date {
            let parser = DateFormatter()
            parser.dateFormat = "yyyy-MM-dd"
            parser.locale = Locale(identifier: "en_US_POSIX")
            if let parsed = parser.date(from: String(dateStr.prefix(10))) { date = parsed }
        }
        let timeParts = item.time.split(separator: ":").compactMap { Int($0) }
        if timeParts.count >= 2 {
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            comps.hour = timeParts[0]; comps.minute = timeParts[1]
            if let parsed = Calendar.current.date(from: comps) { time = parsed }
        }
    }

    private func loadNodes() async {
        do {
            let response = try await APIClient.shared.getChildHomeNodes()
            nodes = response.items
        } catch {
            statusText = error.localizedDescription
        }
    }

    // MARK: - Save

    private func save() {
        if !isDateMode && weekdaysSelected.isEmpty {
            statusText = "Select at least one weekday"
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let dateString = dateFormatter.string(from: date)

        let timeComps = Calendar.current.dateComponents([.hour, .minute], from: time)
        let timeString = String(format: "%02d:%02d", timeComps.hour ?? 0, timeComps.minute ?? 0)

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let mode = isDateMode ? "DATE" : "WEEKDAY"
        let weekdays = isDateMode ? [] : weekdaysSelected.sorted()

        isSaving = true
        statusText = ""
        Task {
            do {
                if let item {
                    _ = try await APIClient.shared.updateScheduleItem(id: item.id, body: UpdateScheduleItemRequest(
                        mode: mode,
                        name: trimmedName.isEmpty ? nil : trimmedName,
                        weekdays: weekdays,
                        date: isDateMode ? dateString : nil,
                        time: timeString,
                        cards: nil,
                        isEnabled: nil,
                        forceShowChildHomeNodeIds: Array(forceShowIds),
                        forceHideChildHomeNodeIds: Array(forceHideIds)
                    ))
                } else if let card {
                    _ = try await APIClient.shared.createScheduleItem(CreateScheduleItemRequest(
                        mode: mode,
                        name: trimmedName.isEmpty ? nil : trimmedName,
                        weekdays: weekdays,
                        date: isDateMode ? dateString : nil,
                        time: timeString,
                        cards: [card],
                        sortOrder: nil,
                        isEnabled: true,
                        forceShowChildHomeNodeIds: Array(forceShowIds),
                        forceHideChildHomeNodeIds: Array(forceHideIds)
                    ))
                }
                isSaving = false
                dismiss()
                onDone()
            } catch {
                isSaving = false
                statusText = "Failed: \(error.localizedDescription)"
            }
        }
    }
}
