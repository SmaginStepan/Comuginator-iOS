import SwiftUI
import UIKit

/// Drop-in replacement for AsyncImage that injects the Bearer token for
/// comuginator.com URLs and caches results in memory.
struct AuthImageView: View {
    let urlString: String?

    @State private var uiImage: UIImage? = nil

    private static let cache = NSCache<NSString, UIImage>()

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.secondary.opacity(0.15)
            }
        }
        .task(id: urlString) { await load() }
    }

    private func load() async {
        guard let urlString, !urlString.isEmpty,
              let url = URL(string: urlString) else { return }

        if let cached = Self.cache.object(forKey: urlString as NSString) {
            uiImage = cached
            return
        }

        var request = URLRequest(url: url)
        if url.host?.hasSuffix("comuginator.com") == true,
           let token = SessionStore.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            // Protected images resolve against the active family — without this
            // header the server uses the device's oldest family and may 404.
            if let familyId = SessionStore.shared.familyId {
                request.setValue(familyId, forHTTPHeaderField: "X-Family-Id")
            }
        }

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let img = UIImage(data: data) else { return }

        Self.cache.setObject(img, forKey: urlString as NSString)
        await MainActor.run { uiImage = img }
    }
}
