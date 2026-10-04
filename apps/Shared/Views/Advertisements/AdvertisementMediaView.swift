import MasterDanceCore
import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

@MainActor
struct AdvertisementMediaView: View {
    let model: AppModel
    let media: AdvertisementMedia?
    var contentMode: ContentMode = .fill
    var cacheRevision: Date?

    @State private var data: Data?
    @State private var isLoading = false
    @State private var displayedStoragePath: String?

    init(
        model: AppModel,
        media: AdvertisementMedia?,
        contentMode: ContentMode = .fill,
        cacheRevision: Date? = nil
    ) {
        self.model = model
        self.media = media
        self.contentMode = contentMode
        self.cacheRevision = cacheRevision
    }

    var body: some View {
        Group {
            if let data {
                AdvertisementDataImage(data: data, contentMode: contentMode)
            } else {
                ZStack {
                    Rectangle().fill(.quaternary.opacity(0.5))
                    if isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .clipped()
        .task(id: mediaTaskID) {
            guard let path = media?.storagePath, !path.isEmpty else {
                data = nil
                displayedStoragePath = nil
                isLoading = false
                return
            }

            if displayedStoragePath != path {
                data = nil
            }
            displayedStoragePath = path
            isLoading = data == nil

            let key = PersistentMediaCache.resourceKey(
                namespace: "advertisement",
                storagePath: path,
                revision: cacheRevision
            )
            let cached = await PersistentMediaCache.shared.lookup(for: key)
            guard !Task.isCancelled else { return }
            if let cached {
                data = cached.data
                isLoading = false
                if cached.isFresh { return }
            }

            do {
                let refreshed = try await PersistentMediaCache.shared.refresh(key: key) {
                    try await model.downloadAdvertisementMediaData(storagePath: path)
                }
                guard !Task.isCancelled else { return }
                data = refreshed
            } catch {
                // Keep the last successful disk copy when the device is offline.
            }
            isLoading = false
        }
    }

    private var mediaTaskID: String {
        guard let path = media?.storagePath, !path.isEmpty else { return "advertisement|none" }
        return PersistentMediaCache.resourceKey(
            namespace: "advertisement",
            storagePath: path,
            revision: cacheRevision
        )
    }
}

struct AdvertisementDataImage: View {
    let data: Data
    var contentMode: ContentMode = .fill

    @ViewBuilder
    var body: some View {
#if os(macOS)
        if let image = NSImage(data: data) {
            rendered(Image(nsImage: image))
        } else {
            rendered(Image(systemName: "photo.badge.exclamationmark"))
        }
#elseif os(iOS)
        if let image = UIImage(data: data) {
            rendered(Image(uiImage: image))
        } else {
            rendered(Image(systemName: "photo.badge.exclamationmark"))
        }
#endif
    }

    private func rendered(_ image: Image) -> some View {
        image
            .resizable()
            .aspectRatio(contentMode: contentMode)
    }
}
