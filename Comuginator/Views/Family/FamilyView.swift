import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - Navigation destinations

enum FamilyDestination: Hashable {
    case composeMessage(targetUserId: String, targetUserName: String)
    case messageHistory(targetUserId: String, targetUserName: String)
    case library
    case childHome
    case schedule
    case settings
}

// MARK: - Main view

struct FamilyView: View {
    @StateObject private var vm = FamilyViewModel()
    @EnvironmentObject private var appState: AppState

    // Rename dialogs
    @State private var showRenameFamily = false
    @State private var renameFamilyText = ""
    @State private var renameUserTarget: UserDto?
    @State private var renameUserText = ""
    @State private var renameDeviceTarget: DeviceDto?
    @State private var renameDeviceText = ""

    // Volume sheet
    @State private var volumeTarget: DeviceDto?
    @State private var volumeSlider: Double = 50

    // Navigation
    @State private var navPath = NavigationPath()

    // Delete confirmations
    @State private var showDeleteFamily = false
    @State private var deleteUserTarget: UserDto?
    @State private var deleteDeviceTarget: DeviceDto?

    // Join another family
    @State private var showJoinAnother = false
    @State private var joinAnotherCode = ""

    var body: some View {
        NavigationStack(path: $navPath) {
            List {
                // Status row
                if !vm.statusText.isEmpty {
                    Text(vm.statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }

                // Invite card
                if let invite = vm.inviteDisplay {
                    inviteSection(invite)
                }

                // Users + their devices
                ForEach(vm.users, id: \.id) { user in
                    Section {
                        ForEach(user.devices ?? [], id: \.id) { device in
                            DeviceRowView(
                                device: device,
                                isMyDevice: device.deviceId == vm.myDeviceId,
                                volume: vm.effectiveVolume(for: device),
                                onVolume: {
                                    volumeTarget = device
                                    volumeSlider = Double(vm.effectiveVolume(for: device) ?? 50)
                                },
                                onRename: {
                                    renameDeviceTarget = device
                                    renameDeviceText = device.name
                                },
                                onDelete: { deleteDeviceTarget = device }
                            )
                        }
                    } header: {
                        UserHeaderView(
                            user: user,
                            isParentViewer: vm.isParent,
                            onSend: { navigateTo(.composeMessage(targetUserId: user.id, targetUserName: user.name)) },
                            onHistory: { navigateTo(.messageHistory(targetUserId: user.id, targetUserName: user.name)) },
                            onRename: { renameUserTarget = user; renameUserText = user.name },
                            onDelete: { deleteUserTarget = user }
                        )
                    }
                }

                // Quick-access buttons
                Section {
                    NavigationLink(value: FamilyDestination.library) {
                        Label("Library", systemImage: "photo.on.rectangle")
                    }
                    NavigationLink(value: FamilyDestination.childHome) {
                        Label("Child Home (Editor)", systemImage: "house")
                    }
                    if vm.isParent {
                        NavigationLink(value: FamilyDestination.schedule) {
                            Label("Schedule", systemImage: "calendar.badge.clock")
                        }
                    }
                }
            }
            .navigationTitle(vm.familyName.isEmpty ? Text("Family") : Text(vm.familyName))
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbar }
            .navigationDestination(for: FamilyDestination.self) { destination in
                switch destination {
                case .composeMessage(let id, let name):
                    ComposeMessageView(targetUserId: id, targetUserName: name)
                case .messageHistory(let id, let name):
                    MessageHistoryView(targetUserId: id, targetUserName: name)
                case .library:   LibraryView()
                case .childHome: ChildHomeView()
                case .schedule:  ScheduleView()
                case .settings:  SettingsView()
                }
            }
            .refreshable { await vm.loadFamily() }
            .overlay { if vm.isLoading { loadingOverlay } }
        }
        .task {
            await vm.loadFamily()
            await vm.sendHeartbeat()
            BackgroundTaskHandler.scheduleHeartbeat()
        }
        .onAppear { vm.startRefreshLoop() }
        .onDisappear { vm.stopRefreshLoop() }
        .onChange(of: vm.shouldLogout) { _, logout in
            if logout { appState.isLoggedIn = false }
        }
        // Join another family
        .alert("Join Another Family", isPresented: $showJoinAnother) {
            TextField("Invite code", text: $joinAnotherCode)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
            Button("Join") {
                Task { await vm.joinAnotherFamily(code: joinAnotherCode) }
                joinAnotherCode = ""
            }
            Button("Cancel", role: .cancel) { joinAnotherCode = "" }
        }
        // Rename family
        .alert("Rename Family", isPresented: $showRenameFamily) {
            TextField("Family name", text: $renameFamilyText)
            Button("Save") { Task { await vm.updateFamilyName(renameFamilyText) } }
            Button("Cancel", role: .cancel) {}
        }
        // Rename user
        .alert("Rename User", isPresented: Binding(
            get: { renameUserTarget != nil },
            set: { if !$0 { renameUserTarget = nil } }
        )) {
            TextField("User name", text: $renameUserText)
            Button("Save") {
                if let user = renameUserTarget {
                    Task { await vm.updateUserName(userId: user.id, name: renameUserText) }
                }
                renameUserTarget = nil
            }
            Button("Cancel", role: .cancel) { renameUserTarget = nil }
        }
        // Rename device
        .alert("Rename Device", isPresented: Binding(
            get: { renameDeviceTarget != nil },
            set: { if !$0 { renameDeviceTarget = nil } }
        )) {
            TextField("Device name", text: $renameDeviceText)
            Button("Save") {
                if let device = renameDeviceTarget {
                    Task { await vm.updateDeviceName(deviceId: device.deviceId, name: renameDeviceText) }
                }
                renameDeviceTarget = nil
            }
            Button("Cancel", role: .cancel) { renameDeviceTarget = nil }
        }
        // Delete family
        .confirmationDialog("Delete family?", isPresented: $showDeleteFamily, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await vm.deleteFamily() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This cannot be undone.") }
        // Delete user
        .confirmationDialog(
            "Delete \(deleteUserTarget?.name ?? "user")?",
            isPresented: Binding(get: { deleteUserTarget != nil }, set: { if !$0 { deleteUserTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let user = deleteUserTarget { Task { await vm.deleteUser(userId: user.id) } }
                deleteUserTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteUserTarget = nil }
        }
        // Delete device
        .confirmationDialog(
            "Delete \(deleteDeviceTarget?.name ?? "device")?",
            isPresented: Binding(get: { deleteDeviceTarget != nil }, set: { if !$0 { deleteDeviceTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let device = deleteDeviceTarget { Task { await vm.deleteDevice(deviceId: device.deviceId) } }
                deleteDeviceTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteDeviceTarget = nil }
        }
        // Volume sheet
        .sheet(item: $volumeTarget) { device in
            VolumeSheet(
                deviceName: device.name,
                initial: volumeSlider,
                onApply: { vol in
                    Task { await vm.sendSetVolumeCommand(deviceId: device.deviceId, volume: Int(vol)) }
                }
            )
            .presentationDetents([.height(240)])
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if vm.isParent {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button("Invite Parent") { Task { await vm.createInvite(role: "PARENT") } }
                    Button("Invite Child")  { Task { await vm.createInvite(role: "CHILD") } }
                } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Rename Family") {
                    renameFamilyText = vm.familyName
                    showRenameFamily = true
                }
                Button("Refresh") { Task { await vm.loadFamily() } }
                Button("Send Heartbeat") { Task { await vm.sendHeartbeat() } }
                Button {
                    navigateTo(.settings)
                } label: {
                    Label("Settings", systemImage: "gear")
                }
                Divider()
                // Family switcher
                if vm.families.count > 1 {
                    Menu("Switch Family") {
                        ForEach(vm.families) { family in
                            Button {
                                vm.setActiveFamily(family.familyId)
                            } label: {
                                if family.familyId == SessionStore.shared.familyId {
                                    Label(family.name ?? family.familyId, systemImage: "checkmark")
                                } else {
                                    Text(family.name ?? family.familyId)
                                }
                            }
                        }
                    }
                }
                Button("Join Another Family") { showJoinAnother = true }
                Divider()
                Button("Delete Family", role: .destructive) { showDeleteFamily = true }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Invite section

    @ViewBuilder
    private func inviteSection(_ invite: InviteDisplay) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(invite.code, systemImage: "ticket")
                            .font(.title2.monospaced().bold())
                        Text("Role: \(invite.role)")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("Expires: \(TimeFormat.dateTime(invite.expiresAt))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let qr = makeQRImage("comuginator://join?code=\(invite.code)") {
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 90, height: 90)
                    }
                }
                Button("Dismiss", role: .cancel) { vm.clearInvite() }
                    .font(.footnote)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Active Invite")
        }
    }

    // MARK: - Loading overlay

    private var loadingOverlay: some View {
        ProgressView()
            .scaleEffect(1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
    }

    // MARK: - Navigation helper

    private func navigateTo(_ dest: FamilyDestination) {
        navPath.append(dest)
    }

    // MARK: - QR helper

    private func makeQRImage(_ string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - User header

private struct UserHeaderView: View {
    let user: UserDto
    let isParentViewer: Bool
    let onSend: () -> Void
    let onHistory: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Avatar placeholder
            Group {
                if user.avatarImageUrl != nil {
                    AuthImageView(urlString: user.avatarImageUrl)
                } else {
                    Image(systemName: "person.circle.fill").resizable().foregroundStyle(.secondary)
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(user.name).font(.headline).foregroundStyle(.primary)
                Text(user.role.capitalized).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            if isParentViewer {
                Button { onSend() } label: {
                    Image(systemName: "bubble.left.fill").foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                Button { onHistory() } label: {
                    Image(systemName: "clock.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Menu {
                Button("Rename") { onRename() }
                Button("Delete", role: .destructive) { onDelete() }
            } label: {
                Image(systemName: "ellipsis").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
        .textCase(nil)
    }
}

// MARK: - Device row

private struct DeviceRowView: View {
    let device: DeviceDto
    let isMyDevice: Bool
    let volume: Int?
    let onVolume: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isMyDevice ? "iphone.badge.play" : "iphone")
                .foregroundStyle(isMyDevice ? .blue : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name).font(.subheadline)
                HStack(spacing: 8) {
                    if let battery = device.state?.batteryPercent {
                        Label("\(battery)%", systemImage: batteryIcon(battery, device.state?.isCharging == true))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if let lastSeen = device.lastSeenAt {
                        Text(TimeFormat.dateTime(lastSeen))
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }

            Spacer()

            if let vol = volume {
                Button {
                    onVolume()
                } label: {
                    Label("\(vol)%", systemImage: "speaker.wave.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Menu {
                Button("Set Volume") { onVolume() }
                Button("Rename")     { onRename() }
                Button("Delete", role: .destructive) { onDelete() }
            } label: {
                Image(systemName: "ellipsis").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    private func batteryIcon(_ percent: Int, _ charging: Bool) -> String {
        if charging { return "battery.100.bolt" }
        if percent > 75 { return "battery.100" }
        if percent > 50 { return "battery.75" }
        if percent > 25 { return "battery.50" }
        return "battery.25"
    }
}

// MARK: - Volume sheet

private struct VolumeSheet: View {
    let deviceName: String
    let initial: Double
    let onApply: (Double) -> Void

    @State private var value: Double
    @Environment(\.dismiss) private var dismiss

    init(deviceName: String, initial: Double, onApply: @escaping (Double) -> Void) {
        self.deviceName = deviceName
        self.initial = initial
        self.onApply = onApply
        _value = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("\(Int(value))%")
                    .font(.title.bold())
                Slider(value: $value, in: 0...100, step: 1)
                    .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Volume — \(deviceName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { onApply(value); dismiss() }
                }
            }
        }
    }
}
