import SwiftUI

struct SettingsView: View {
    @StateObject private var vm = SettingsViewModel()
    @EnvironmentObject private var appState: AppState

    @State private var showRenameUser = false
    @State private var renameUserText = ""
    @State private var showRenameDevice = false
    @State private var renameDeviceText = ""
    @State private var showAvatarPicker = false
    @State private var showLogoutConfirm = false
    @State private var showDeleteAccount = false

    // Notifications
    @State private var notificationsEnabled = NotificationPolicy.isEnabled()
    @State private var notificationRules = NotificationSettingsStore.shared.getRules()
    @State private var showAddRule = false

    var body: some View {
        Form {
            // ── Profile ──────────────────────────────────────────────────
            Section("Profile") {
                HStack(spacing: 16) {
                    // Avatar — tap to change
                    Button { showAvatarPicker = true } label: {
                        ZStack(alignment: .bottomTrailing) {
                            Group {
                                if vm.myUser?.avatarImageUrl != nil {
                                    AuthImageView(urlString: vm.myUser?.avatarImageUrl)
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable().foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())

                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .background(Color(.systemBackground), in: Circle())
                        }
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(vm.myUser?.name ?? SessionStore.shared.userName ?? "—")
                            .font(.headline)

                        Text(vm.role == "PARENT" ? "Parent" : "Child")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(
                                vm.role == "PARENT"
                                    ? Color.blue.opacity(0.12)
                                    : Color.green.opacity(0.12),
                                in: Capsule()
                            )
                            .foregroundStyle(vm.role == "PARENT" ? .blue : .green)
                    }

                    Spacer()

                    Button("Edit") {
                        renameUserText = vm.myUser?.name ?? SessionStore.shared.userName ?? ""
                        showRenameUser = true
                    }
                    .font(.subheadline)
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 4)
            }

            // ── Device ───────────────────────────────────────────────────
            Section("This Device") {
                LabeledContent("Name") {
                    Text(vm.deviceName.isEmpty ? "Not set" : vm.deviceName)
                        .foregroundStyle(vm.deviceName.isEmpty ? .secondary : .primary)
                }
                Button("Rename Device") {
                    renameDeviceText = vm.deviceName
                    showRenameDevice = true
                }
            }

            // ── Family ───────────────────────────────────────────────────
            Section("Family") {
                LabeledContent("Name") {
                    Text(vm.familyName.isEmpty ? "—" : vm.familyName)
                        .foregroundStyle(vm.familyName.isEmpty ? .secondary : .primary)
                }
            }

            // ── Notifications ────────────────────────────────────────────
            Section {
                Toggle("Notifications", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, newValue in
                        NotificationSettingsStore.shared.notificationsEnabledManually = newValue
                    }

                ForEach(notificationRules) { rule in
                    NotificationRuleRow(rule: rule)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                NotificationSettingsStore.shared.removeRule(id: rule.id)
                                reloadNotificationState()
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                }

                Button {
                    showAddRule = true
                } label: {
                    Label("Add Rule", systemImage: "plus.circle")
                }
            } header: {
                Text("Notifications")
            } footer: {
                Text("Rules turn notifications on or off automatically at the given time. The most recent event wins.")
            }

            // ── App info ─────────────────────────────────────────────────
            Section("App") {
                LabeledContent("Version", value: "\(vm.appVersion) (\(vm.buildNumber))")
            }

            // ── Status ───────────────────────────────────────────────────
            if !vm.statusText.isEmpty {
                Section {
                    Text(vm.statusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            // ── Account actions ──────────────────────────────────────────
            Section {
                Button("Log Out") { showLogoutConfirm = true }
                    .foregroundStyle(.orange)
                Button("Delete Account", role: .destructive) {
                    showDeleteAccount = true
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if vm.isLoading { loadingOverlay } }
        .refreshable { await vm.load() }
        .task { await vm.load() }
        .onChange(of: vm.shouldLogout) { _, logout in
            if logout { appState.isLoggedIn = false }
        }
        // Rename self
        .alert("Change Name", isPresented: $showRenameUser) {
            TextField("Your name", text: $renameUserText)
                .autocorrectionDisabled()
            Button("Save") { Task { await vm.updateUserName(renameUserText) } }
            Button("Cancel", role: .cancel) {}
        }
        // Rename device
        .alert("Rename Device", isPresented: $showRenameDevice) {
            TextField("Device name", text: $renameDeviceText)
                .autocorrectionDisabled()
            Button("Save") { Task { await vm.updateDeviceName(renameDeviceText) } }
            Button("Cancel", role: .cancel) {}
        }
        // Add notification rule
        .sheet(isPresented: $showAddRule) {
            NotificationRuleEditorSheet {
                showAddRule = false
                reloadNotificationState()
            }
            .presentationDetents([.medium, .large])
        }
        // Avatar picker
        .sheet(isPresented: $showAvatarPicker) {
            LibraryItemPickerView { itemId in
                Task { await vm.updateAvatar(itemId: itemId) }
            }
        }
        // Logout
        .confirmationDialog("Log out of Comuginator?",
                            isPresented: $showLogoutConfirm,
                            titleVisibility: .visible) {
            Button("Log Out", role: .destructive) { vm.logout() }
            Button("Cancel", role: .cancel) {}
        }
        // Delete account
        .confirmationDialog("Delete your account?",
                            isPresented: $showDeleteAccount,
                            titleVisibility: .visible) {
            Button("Delete Account", role: .destructive) {
                Task { await vm.deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your account. Your family remains unless you are the last member.")
        }
    }

    private func reloadNotificationState() {
        notificationRules = NotificationSettingsStore.shared.getRules()
        notificationsEnabled = NotificationPolicy.isEnabled()
    }

    private var loadingOverlay: some View {
        ProgressView().scaleEffect(1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
    }
}

// MARK: - Notification rule row

private struct NotificationRuleRow: View {
    let rule: NotificationRule

    private var scheduleText: String {
        if let date = rule.date {
            return "\(TimeFormat.date(date)) \(rule.time)"
        }
        let names = rule.weekdays.map { ScheduleViewModel.weekdayName($0) }.joined(separator: ", ")
        return "\(names) \(rule.time)"
    }

    var body: some View {
        HStack {
            Image(systemName: rule.enable ? "bell.fill" : "bell.slash.fill")
                .foregroundStyle(rule.enable ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.enable ? "Turn on" : "Turn off").font(.subheadline)
                Text(scheduleText).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Notification rule editor

private struct NotificationRuleEditorSheet: View {
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var enable = false
    @State private var isDateMode = false
    @State private var date = Date()
    @State private var weekdaysSelected: Set<Int> = []
    @State private var time = Date()

    private let weekdayLabels = [1: "Mon", 2: "Tue", 3: "Wed", 4: "Thu", 5: "Fri", 6: "Sat", 7: "Sun"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Action", selection: $enable) {
                        Text("Turn notifications off").tag(false)
                        Text("Turn notifications on").tag(true)
                    }
                }

                Section("When") {
                    Picker("Repeat", selection: $isDateMode) {
                        Text("Weekly").tag(false)
                        Text("Exact date").tag(true)
                    }
                    .pickerStyle(.segmented)

                    if isDateMode {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                    } else {
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
            }
            .navigationTitle("New Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss(); onDone() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isDateMode && weekdaysSelected.isEmpty)
                }
            }
        }
    }

    private func save() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        let timeComps = Calendar.current.dateComponents([.hour, .minute], from: time)
        let timeString = String(format: "%02d:%02d", timeComps.hour ?? 0, timeComps.minute ?? 0)

        NotificationSettingsStore.shared.addRule(NotificationRule(
            id: UUID().uuidString,
            enable: enable,
            weekdays: isDateMode ? [] : weekdaysSelected.sorted(),
            date: isDateMode ? dateFormatter.string(from: date) : nil,
            time: timeString
        ))
        dismiss()
        onDone()
    }
}
