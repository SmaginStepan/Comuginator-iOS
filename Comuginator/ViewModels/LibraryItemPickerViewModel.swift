import SwiftUI
import Combine

@MainActor
final class LibraryItemPickerViewModel: ObservableObject {
    // Library browse
    @Published var allItems: [LibraryItemDto] = []
    @Published var sets: [LibrarySetDto] = []
    @Published var selectedSetId: String? = nil

    // ARASAAC
    @Published var arasaacResults: [ArasaacItemDto] = []
    @Published var arasaacQuery = ""
    @Published var isSearchingArasaac = false

    // Confirmation (after capture/search selection)
    @Published var pendingImage: UIImage? = nil
    @Published var pendingArasaacItem: ArasaacItemDto? = nil
    @Published var pendingLabel = ""

    @Published var isLoading = false
    @Published var isUploading = false
    @Published var statusText = ""

    var filteredItems: [LibraryItemDto] {
        guard let setId = selectedSetId else { return allItems }
        return allItems.filter { $0.id == setId } // placeholder until set-items are loaded
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let itemsResp = APIClient.shared.getLibraryItems()
            async let setsResp  = APIClient.shared.getLibrarySets()
            allItems = try await itemsResp.items
            sets     = try await setsResp.sets
        } catch {
            statusText = error.localizedDescription
        }
    }

    func loadSet(_ setId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await APIClient.shared.getLibrarySet(setId: setId)
            allItems = result.set.items
        } catch {
            statusText = error.localizedDescription
        }
    }

    // MARK: - ARASAAC

    func searchArasaac() async {
        guard !arasaacQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearchingArasaac = true
        defer { isSearchingArasaac = false }
        do {
            arasaacResults = try await APIClient.shared.searchArasaac(query: arasaacQuery).items
        } catch {
            statusText = error.localizedDescription
        }
    }

    func selectArasaacItem(_ item: ArasaacItemDto) {
        pendingArasaacItem = item
        pendingLabel = item.label ?? ""
    }

    // MARK: - Confirmation / upload

    func setPendingImage(_ image: UIImage) {
        pendingImage = image
        pendingLabel = ""
    }

    func cancelPending() {
        pendingImage = nil
        pendingArasaacItem = nil
        pendingLabel = ""
    }

    /// Upload photo → returns new item ID
    func uploadAndConfirm() async -> String? {
        guard let image = pendingImage,
              let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        isUploading = true
        defer { isUploading = false }
        do {
            let r = try await APIClient.shared.uploadPhoto(imageData: data, fileName: "photo_\(UUID().uuidString).jpg")
            cancelPending()
            return r.item.id
        } catch {
            statusText = "Upload failed: \(error.localizedDescription)"
            return nil
        }
    }

    /// Create ARASAAC item → returns new item ID
    func confirmArasaac() async -> String? {
        guard let item = pendingArasaacItem,
              let ref = item.id.isEmpty ? nil : item.id else { return nil }
        isUploading = true
        defer { isUploading = false }
        do {
            let label = pendingLabel.trimmingCharacters(in: .whitespaces).isEmpty
                ? (item.label ?? ref) : pendingLabel
            let r = try await APIClient.shared.createArasaacLibraryItem(
                CreateArasaacLibraryItemRequest(label: label, sourceRef: ref)
            )
            cancelPending()
            return r.item.id
        } catch {
            statusText = "Failed: \(error.localizedDescription)"
            return nil
        }
    }
}
