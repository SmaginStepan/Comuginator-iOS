import SwiftUI

// MARK: - ChildHomeView

struct ChildHomeView: View {
    @StateObject private var vm = ChildHomeViewModel()

    @State private var showAddSheet = false
    @State private var editTarget: ChildHomeNodeDto? = nil

    private let columns = [GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            // Preview banner so the parent knows they're simulating the child
            if vm.previewMode {
                HStack(spacing: 6) {
                    Image(systemName: "eye.fill")
                    Text("Preview — as the child sees it")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.blue)
            }

            // Breadcrumb bar — hidden in preview (matches Android)
            if !vm.breadcrumbs.isEmpty && !vm.previewMode {
                breadcrumbBar
            }

            if vm.isLoading && vm.nodes.isEmpty {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.isParent && !vm.previewMode {
                editorList
            } else {
                boardGrid
            }
        }
        .navigationTitle(vm.previewMode
                         ? Text("Preview")
                         : (vm.breadcrumbs.last.map { Text($0.name) } ?? Text("Child Home")))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .refreshable { await vm.load(parentId: vm.currentParentId) }
        .task { await vm.load() }
        .overlay {
            if vm.isLoading && !vm.nodes.isEmpty {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        // Add new node
        .sheet(isPresented: $showAddSheet) {
            NodeEditorSheet(vm: vm, node: nil) { showAddSheet = false }
        }
        // Edit existing node
        .sheet(item: $editTarget) { node in
            NodeEditorSheet(vm: vm, node: node) { editTarget = nil }
        }
    }

    // MARK: - Breadcrumb bar

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button { vm.navigateToRoot() } label: {
                    Image(systemName: "house")
                        .font(.caption)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ForEach(vm.breadcrumbs.indices, id: \.self) { i in
                    let crumb = vm.breadcrumbs[i]
                    let isLast = i == vm.breadcrumbs.count - 1

                    if isLast {
                        Text(crumb.name)
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                    } else {
                        Button { vm.navigateToLevel(i) } label: {
                            Text(crumb.name).font(.caption)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    // MARK: - Board grid (child-facing / parent preview)

    private var boardGrid: some View {
        // Board grid is shown to children and to parents in preview — both see
        // only visible tiles, exactly as the child experiences it.
        let displayNodes = vm.visibleNodes
        return Group {
            if displayNodes.isEmpty {
                ContentUnavailableView(
                    "Nothing Here",
                    systemImage: "square.grid.2x2"
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(displayNodes) { node in
                            NodeTileView(node: node, vm: vm)
                        }
                    }
                    .padding()
                }
                // Tap anywhere during blink to dismiss
                .onTapGesture {
                    if vm.blinkingNodeId != nil { vm.stopBlink() }
                }
            }
        }
    }

    // MARK: - Editor list

    private var editorList: some View {
        List {
            Section {
                ForEach(vm.nodes) { node in
                    EditorRowView(node: node) {
                        Task { await vm.toggleVisibility(node) }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editTarget = node }
                    .swipeActions(edge: .leading) {
                        Button {
                            Task { await vm.toggleVisibility(node) }
                        } label: {
                            Label(node.isVisible ? "Hide" : "Show",
                                  systemImage: node.isVisible ? "eye.slash" : "eye")
                        }
                        .tint(node.isVisible ? .gray : .green)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await vm.deleteNode(nodeId: node.id) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onMove { from, to in
                    vm.nodes.move(fromOffsets: from, toOffset: to)
                    Task { await vm.persistNodeOrder() }
                }
            }

            Section {
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add Tile", systemImage: "plus.circle")
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Back button within child-home hierarchy (different from NavigationStack back)
        if !vm.breadcrumbs.isEmpty {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    vm.navigateBack()
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
        }

        if vm.isParent {
            if vm.previewMode {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { withAnimation { vm.stopPreview() } } label: {
                        Label("Stop", systemImage: "stop.circle")
                    }
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { withAnimation { vm.startPreview() } } label: {
                        Label("Preview", systemImage: "play.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

// MARK: - Node tile (child board)

private struct NodeTileView: View {
    let node: ChildHomeNodeDto
    @ObservedObject var vm: ChildHomeViewModel

    private var label: String {
        node.labelOverride ?? node.item?.label ?? ""
    }
    private var imageUrl: String? { node.item?.imageUrl }
    private var isMenu: Bool { node.type == "MENU" }

    private var isHiddenForParent: Bool { vm.isParent && !node.isVisible }

    private var opacity: Double {
        if let blinkId = vm.blinkingNodeId {
            return node.id == blinkId ? vm.blinkOpacity : 0.1
        }
        // Fade hidden tiles so parents can tell them apart from visible ones.
        return isHiddenForParent ? 0.4 : 1.0
    }

    var body: some View {
        Button {
            if vm.blinkingNodeId != nil {
                vm.stopBlink()
                return
            }
            if isMenu {
                vm.navigateInto(node)
            } else if vm.previewMode {
                // Preview: blink locally only, don't notify parents
                vm.previewAction(node)
            } else {
                Task { await vm.requestAction(node) }
            }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if imageUrl != nil {
                            AuthImageView(urlString: imageUrl)
                        } else {
                            Color.secondary.opacity(0.15)
                                .overlay(
                                    Image(systemName: isMenu ? "folder.fill" : "hand.tap.fill")
                                        .font(.largeTitle)
                                        .foregroundStyle(.secondary.opacity(0.6))
                                )
                        }
                    }
                    .frame(width: 90, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Menu indicator badge
                    if isMenu {
                        Image(systemName: "arrow.forward.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(.blue, in: Circle())
                            .padding(4)
                    }

                    // Hidden badge (visible to parents only)
                    if vm.isParent && !node.isVisible {
                        Image(systemName: "eye.slash.fill")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(Color.black.opacity(0.55), in: Circle())
                            .padding(4)
                            .frame(maxWidth: .infinity, maxHeight: .infinity,
                                   alignment: .bottomTrailing)
                    }
                }

                Text(label)
                    .font(.caption2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 90)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isHiddenForParent
                          ? Color.secondary.opacity(0.12)
                          : Color(.systemBackground))
                    .shadow(color: .black.opacity(isHiddenForParent ? 0 : 0.07), radius: 4, y: 2)
            )
            .overlay {
                // Dashed outline marks hidden tiles for parents.
                if isHiddenForParent {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(opacity)
        .animation(.easeInOut(duration: 0.1), value: opacity)
    }
}

// MARK: - Editor row

private struct EditorRowView: View {
    let node: ChildHomeNodeDto
    let onToggleVisibility: () -> Void

    private var label: String {
        node.labelOverride ?? node.item?.label ?? "(no label)"
    }
    private var isMenu: Bool { node.type == "MENU" }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if node.item?.imageUrl != nil {
                    AuthImageView(urlString: node.item?.imageUrl)
                } else {
                    Color.secondary.opacity(0.15)
                        .overlay(
                            Image(systemName: isMenu ? "folder" : "hand.tap")
                                .foregroundStyle(.secondary)
                        )
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.subheadline)
                HStack(spacing: 6) {
                    Text(LocalizedStringKey(isMenu ? "Menu" : "Action"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !node.isVisible {
                        Label("Hidden", systemImage: "eye.slash")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if node.blinkEnabled && !isMenu {
                        Label("\(node.blinkSeconds ?? 0)s", systemImage: "bolt.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            // Quick show/hide toggle
            Button(action: onToggleVisibility) {
                Image(systemName: node.isVisible ? "eye.fill" : "eye.slash.fill")
                    .font(.body)
                    .foregroundStyle(node.isVisible ? .blue : .secondary)
                    .frame(width: 36, height: 36)
                    .background(
                        (node.isVisible ? Color.blue : Color.secondary).opacity(0.12),
                        in: Circle()
                    )
            }
            .buttonStyle(.borderless)

            Image(systemName: "pencil.circle")
                .foregroundStyle(.blue)
        }
        .padding(.vertical, 2)
        .opacity(node.isVisible ? 1.0 : 0.55)
    }
}

// MARK: - Node editor sheet

struct NodeEditorSheet: View {
    @ObservedObject var vm: ChildHomeViewModel
    let node: ChildHomeNodeDto?
    let onDismiss: () -> Void

    @State private var selectedItemId: String = ""
    @State private var labelOverride: String = ""
    @State private var nodeType: String = "ACTION"
    @State private var targetMode: String = "ALL_PARENTS"
    @State private var blinkEnabled: Bool = true
    @State private var blinkSeconds: Int = 10
    @State private var isVisible: Bool = true
    @State private var showItemPicker = false
    @State private var isSaving = false

    private var isEditing: Bool { node != nil }

    var body: some View {
        NavigationStack {
            Form {
                // Item
                Section("Tile Image") {
                    Button {
                        showItemPicker = true
                    } label: {
                        HStack {
                            if !selectedItemId.isEmpty {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Item selected")
                                    .foregroundStyle(.primary)
                            } else {
                                Image(systemName: "photo.badge.plus")
                                Text("Choose from Library")
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    TextField("Label override (optional)", text: $labelOverride)
                        .autocorrectionDisabled()
                }

                // Type
                Section("Tile Type") {
                    Picker("Type", selection: $nodeType) {
                        Text("Action").tag("ACTION")
                        Text("Menu (sub-board)").tag("MENU")
                    }
                    .pickerStyle(.segmented)

                    if nodeType == "MENU" {
                        Text("Menu tiles open a nested board when tapped.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Action-specific settings
                if nodeType == "ACTION" {
                    Section("Action Settings") {
                        Picker("Notify", selection: $targetMode) {
                            Text("All parents").tag("ALL_PARENTS")
                            Text("Any parent").tag("ANY_PARENT")
                        }

                        Toggle("Blink animation", isOn: $blinkEnabled)

                        if blinkEnabled {
                            Stepper(
                                "Duration: \(blinkSeconds) sec",
                                value: $blinkSeconds,
                                in: 1...60
                            )
                        }
                    }
                }

                // Visibility
                Section {
                    Toggle("Visible to child", isOn: $isVisible)
                } footer: {
                    Text("Hidden tiles are invisible to the child but remain editable.")
                }
            }
            .navigationTitle(Text(LocalizedStringKey(isEditing ? "Edit Tile" : "New Tile")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isSaving)
                }
            }
            .disabled(isSaving)
            .overlay {
                if isSaving { ProgressView() }
            }
        }
        .sheet(isPresented: $showItemPicker) {
            LibraryItemPickerView { itemId in
                selectedItemId = itemId
            }
        }
        .onAppear { populateFromNode() }
    }

    private func populateFromNode() {
        guard let node else { return }
        selectedItemId = node.itemId ?? ""
        labelOverride  = node.labelOverride ?? ""
        nodeType       = node.type
        targetMode     = node.targetMode ?? "ALL_PARENTS"
        blinkEnabled   = node.blinkEnabled
        blinkSeconds   = node.blinkSeconds ?? 10
        isVisible      = node.isVisible
    }

    private func save() {
        isSaving = true
        Task {
            if isEditing {
                await vm.updateNode(
                    nodeId: node!.id,
                    labelOverride: labelOverride,
                    isVisible: isVisible,
                    targetMode: targetMode,
                    blinkEnabled: blinkEnabled,
                    blinkSeconds: blinkSeconds
                )
            } else {
                await vm.createNode(
                    itemId: selectedItemId,
                    type: nodeType,
                    labelOverride: labelOverride.isEmpty ? nil : labelOverride,
                    targetMode: targetMode,
                    blinkEnabled: blinkEnabled,
                    blinkSeconds: blinkSeconds
                )
            }
            isSaving = false
            onDismiss()
        }
    }
}
