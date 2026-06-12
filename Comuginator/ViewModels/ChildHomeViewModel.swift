import Foundation
import Combine

@MainActor
final class ChildHomeViewModel: ObservableObject {

    // MARK: - Published state

    @Published var nodes: [ChildHomeNodeDto] = []
    @Published var isLoading = false
    @Published var statusText = ""
    @Published var isEditorMode = false

    // Blink
    @Published var blinkingNodeId: String? = nil
    @Published var blinkOpacity: Double = 1.0

    // Breadcrumb navigation stack: (nodeId, display name)
    @Published var breadcrumbs: [(id: String, name: String)] = []

    // MARK: - Computed

    var currentParentId: String? { breadcrumbs.last?.id }
    var isParent: Bool { SessionStore.shared.role == "PARENT" }

    /// Nodes visible to the child (hidden nodes are still shown to parents in the grid)
    var visibleNodes: [ChildHomeNodeDto] { nodes.filter(\.isVisible) }

    private var blinkTask: Task<Void, Never>?
    private var scheduleObserver: AnyCancellable?

    init() {
        // Reload when the server applies a schedule's show/hide overrides
        scheduleObserver = NotificationCenter.default
            .publisher(for: .childHomeScheduleApplied)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.load(parentId: self.currentParentId) }
            }
    }

    // MARK: - Load

    func load(parentId: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await APIClient.shared.getChildHomeNodes(parentId: parentId)
            nodes = response.items.sorted { $0.sortOrder < $1.sortOrder }
            statusText = ""
        } catch {
            statusText = "Failed to load: \(error.localizedDescription)"
        }
    }

    // MARK: - Hierarchical navigation

    func navigateInto(_ node: ChildHomeNodeDto) {
        let label = node.labelOverride ?? node.item?.label ?? "Board"
        breadcrumbs.append((id: node.id, name: label))
        Task { await load(parentId: node.id) }
    }

    func navigateBack() {
        guard !breadcrumbs.isEmpty else { return }
        breadcrumbs.removeLast()
        Task { await load(parentId: currentParentId) }
    }

    func navigateToLevel(_ index: Int) {
        guard index >= 0, index < breadcrumbs.count else { return }
        breadcrumbs = Array(breadcrumbs[0...index])
        Task { await load(parentId: breadcrumbs.last?.id) }
    }

    func navigateToRoot() {
        breadcrumbs.removeAll()
        Task { await load(parentId: nil) }
    }

    // MARK: - Action (child board)

    func requestAction(_ node: ChildHomeNodeDto) async {
        blinkTask?.cancel()
        do {
            let response = try await APIClient.shared.requestChildHomeAction(nodeId: node.id)
            if response.blinkEnabled, let seconds = response.blinkSeconds, seconds > 0 {
                await startBlink(nodeId: node.id, seconds: seconds)
            }
        } catch {
            statusText = "Action failed: \(error.localizedDescription)"
        }
    }

    private func startBlink(nodeId: String, seconds: Int) async {
        blinkingNodeId = nodeId
        blinkOpacity = 1.0
        let halfCycleMs = 400
        let cycles = max(1, seconds * 1000 / halfCycleMs)

        blinkTask = Task {
            for _ in 0..<cycles {
                try? await Task.sleep(for: .milliseconds(halfCycleMs))
                guard !Task.isCancelled else { break }
                blinkOpacity = blinkOpacity == 1.0 ? 0.25 : 1.0
            }
            blinkingNodeId = nil
            blinkOpacity = 1.0
        }
        await blinkTask?.value
    }

    func stopBlink() {
        blinkTask?.cancel()
        blinkTask = nil
        blinkingNodeId = nil
        blinkOpacity = 1.0
    }

    // MARK: - Editor CRUD

    func createNode(
        itemId: String?,
        type: String,
        labelOverride: String?,
        targetMode: String,
        blinkEnabled: Bool,
        blinkSeconds: Int?
    ) async {
        isLoading = true
        defer { isLoading = false }
        let nextOrder = (nodes.map(\.sortOrder).max() ?? -1) + 1
        let body = CreateChildHomeNodeRequest(
            itemId: itemId.flatMap { $0.isEmpty ? nil : $0 },
            parentId: currentParentId,
            type: type,
            sortOrder: nextOrder,
            targetMode: type == "ACTION" ? targetMode : nil,
            targetUserIds: [],
            blinkEnabled: blinkEnabled,
            blinkSeconds: blinkEnabled ? blinkSeconds : nil
        )
        do {
            let result = try await APIClient.shared.createChildHomeNode(body)
            nodes.append(result.item)
            nodes.sort { $0.sortOrder < $1.sortOrder }
        } catch {
            statusText = "Failed to create: \(error.localizedDescription)"
        }
    }

    func updateNode(
        nodeId: String,
        labelOverride: String?,
        isVisible: Bool,
        targetMode: String,
        blinkEnabled: Bool,
        blinkSeconds: Int?
    ) async {
        isLoading = true
        defer { isLoading = false }
        let trimmedLabel = labelOverride?.trimmingCharacters(in: .whitespaces)
        let body = UpdateChildHomeNodeRequest(
            itemId: nil,
            parentId: nil,
            type: nil,
            sortOrder: nil,
            targetMode: targetMode,
            targetUserIds: nil,
            blinkEnabled: blinkEnabled,
            blinkSeconds: blinkEnabled ? blinkSeconds : nil,
            labelOverride: (trimmedLabel?.isEmpty == false) ? trimmedLabel : nil,
            isVisible: isVisible
        )
        do {
            let result = try await APIClient.shared.updateChildHomeNode(nodeId: nodeId, body: body)
            if let idx = nodes.firstIndex(where: { $0.id == nodeId }) {
                nodes[idx] = result.item
            }
        } catch {
            statusText = "Failed to update: \(error.localizedDescription)"
        }
    }

    func deleteNode(nodeId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await APIClient.shared.deleteChildHomeNode(nodeId: nodeId)
            nodes.removeAll { $0.id == nodeId }
        } catch {
            statusText = "Failed to delete: \(error.localizedDescription)"
        }
    }

    /// Persist current `nodes` array order by PATCHing sortOrder for each node.
    func persistNodeOrder() async {
        let ordered = nodes
        for (index, node) in ordered.enumerated() {
            let body = UpdateChildHomeNodeRequest(
                itemId: nil, parentId: nil, type: nil,
                sortOrder: index,
                targetMode: nil, targetUserIds: nil,
                blinkEnabled: nil, blinkSeconds: nil,
                labelOverride: nil, isVisible: nil
            )
            try? await APIClient.shared.updateChildHomeNode(nodeId: node.id, body: body)
        }
    }
}
