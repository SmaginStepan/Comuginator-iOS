import Foundation
import Combine

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var sets: [LibrarySetDto] = []
    @Published var isLoading = false
    @Published var statusText = ""

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            sets = try await APIClient.shared.getLibrarySets().sets
            statusText = "\(sets.count) set(s)"
        } catch {
            statusText = "Failed: \(error.localizedDescription)"
        }
    }

    func createSet(name: String) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await APIClient.shared.createLibrarySet(
                CreateLibrarySetRequest(name: name, coverItemId: nil, itemIds: [])
            )
            await load()
        } catch {
            statusText = "Failed: \(error.localizedDescription)"
        }
    }

    func persistSetOrder() async {
        let ids = sets.map(\.id)
        do {
            _ = try await APIClient.shared.moveItemsInSet(
                setId: "",
                body: MoveLibrarySetItemsRequest(itemIds: ids)
            )
        } catch {
            // reorder is best-effort; don't surface to user
        }
    }

    func deleteSet(id: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await APIClient.shared.deleteLibrarySet(setId: id)
            await load()
        } catch {
            statusText = "Failed: \(error.localizedDescription)"
        }
    }
}
