import Foundation
import Combine

@MainActor
final class LibrarySetViewModel: ObservableObject {
    @Published var details: LibrarySetDetailsDto?
    @Published var isLoading = false
    @Published var statusText = ""
    @Published var shouldDismiss = false

    var items: [LibraryItemDto] { details?.items ?? [] }

    func load(setId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            details = try await APIClient.shared.getLibrarySet(setId: setId).set
            statusText = "\(details?.items.count ?? 0) item(s)"
        } catch {
            statusText = "Failed: \(error.localizedDescription)"
        }
    }

    func addItem(_ itemId: String, setId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await APIClient.shared.addItemsToSet(
                setId: setId, body: AddItemsToSetRequest(itemIds: [itemId])
            )
            details = result.set
            statusText = "\(details?.items.count ?? 0) item(s)"
        } catch {
            statusText = "Failed: \(error.localizedDescription)"
        }
    }

    func updateName(_ name: String, setId: String) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await APIClient.shared.updateLibrarySet(
                setId: setId, body: UpdateLibrarySetRequest(name: name, coverItemId: nil)
            )
            details = result.set
        } catch {
            statusText = "Failed: \(error.localizedDescription)"
        }
    }

    func updateCover(_ itemId: String, setId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await APIClient.shared.updateLibrarySet(
                setId: setId, body: UpdateLibrarySetRequest(name: nil, coverItemId: itemId)
            )
            details = result.set
        } catch {
            statusText = "Failed: \(error.localizedDescription)"
        }
    }

    func persistItemOrder(setId: String) async {
        let ids = items.map(\.id)
        do {
            _ = try await APIClient.shared.moveItemsInSet(
                setId: setId, body: MoveLibrarySetItemsRequest(itemIds: ids)
            )
        } catch { /* best-effort */ }
    }

    func renameItem(_ itemId: String, label: String, setId: String) async {
        let label = label.trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await APIClient.shared.renameLibraryItem(
                itemId: itemId, body: RenameLibraryItemRequest(label: label)
            )
            await load(setId: setId)
        } catch {
            statusText = "Failed: \(error.localizedDescription)"
        }
    }

    func deleteItem(_ itemId: String, setId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await APIClient.shared.removeItemFromSet(setId: setId, itemId: itemId)
            details = result.set
            statusText = "\(details?.items.count ?? 0) item(s)"
        } catch {
            statusText = "Failed: \(error.localizedDescription)"
        }
    }

    func deleteSet(setId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await APIClient.shared.deleteLibrarySet(setId: setId)
            shouldDismiss = true
        } catch {
            statusText = "Failed: \(error.localizedDescription)"
        }
    }
}
