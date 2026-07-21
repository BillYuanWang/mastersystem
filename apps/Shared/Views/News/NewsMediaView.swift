import MasterDanceCore
import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

@MainActor
struct NewsMediaView: View {
    let model: AppModel
    let image: NewsArticleImage?
    var contentMode: ContentMode = .fill

    @State private var data: Data?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let data {
                NewsDataImage(data: data, contentMode: contentMode)
            } else {
                ZStack {
                    Rectangle().fill(.quaternary.opacity(0.5))
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .clipped()
        .task(id: image?.storagePath) {
            data = nil
            guard let path = image?.storagePath, !path.isEmpty else {
                isLoading = false
                return
            }
            isLoading = true
            data = await model.newsMediaData(storagePath: path)
            isLoading = false
        }
    }
}

struct NewsDataImage: View {
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
