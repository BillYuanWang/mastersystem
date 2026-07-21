#if os(iOS)
import MasterDanceCore
import SwiftUI
import UIKit

@MainActor
struct MobileAdvertisementSection: View {
    let model: AppModel

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        let advertisements = model.activeAdvertisements()
        if !advertisements.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Divider()
                    .padding(.bottom, 4)

                HStack(alignment: .firstTextBaseline) {
                    Text("广告")
                        .mdFont(.bodyStrong)
                        .foregroundStyle(theme.primaryText)
                    Spacer()
                    Text(advertisements.count > 1 ? "合作推广 · \(advertisements.count)" : "合作推广")
                        .mdFont(.mono)
                        .foregroundStyle(theme.secondaryText)
                }

                TabView {
                    ForEach(advertisements) { advertisement in
                        MobileAdvertisementCard(model: model, advertisement: advertisement)
                            .padding(.bottom, advertisements.count > 1 ? 16 : 0)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: advertisements.count > 1 ? .automatic : .never))
                .frame(height: advertisements.count > 1 ? 126 : 106)
            }
            .padding(.top, 2)
        }
    }
}

@MainActor
private struct MobileAdvertisementCard: View {
    let model: AppModel
    let advertisement: Advertisement

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        NavigationLink {
            MobileAdvertisementDetailView(model: model, advertisement: advertisement)
        } label: {
            HStack(spacing: 12) {
                AdvertisementMediaView(
                    model: model,
                    media: advertisement.thumbnail,
                    contentMode: .fit
                )
                .frame(width: 82, height: 82)
                .background(theme.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: MDMetrics.radius))
                .overlay {
                    RoundedRectangle(cornerRadius: MDMetrics.radius)
                        .stroke(theme.faintSeparator, lineWidth: 1)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(advertisement.advertiserName)
                            .mdFont(.bodyStrong)
                            .foregroundStyle(theme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)

                        Text("推广")
                            .mdFont(size: 10, weight: .semibold, design: .monospaced)
                            .foregroundStyle(theme.secondaryText)
                            .padding(.horizontal, 5)
                            .frame(height: 19)
                            .overlay {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(theme.separator, lineWidth: 1)
                            }
                    }

                    Text(advertisement.copyText)
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(2)

                    Text("查看广告详情")
                        .mdFont(.compactStrong)
                        .foregroundStyle(theme.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(10)
            .background(theme.raisedSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
            .overlay {
                RoundedRectangle(cornerRadius: MDMetrics.radius)
                    .stroke(theme.faintSeparator, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("推广，\(advertisement.advertiserName)，\(advertisement.copyText)")
        .accessibilityHint("查看完整广告海报")
    }
}

@MainActor
private struct MobileAdvertisementDetailView: View {
    let model: AppModel
    let advertisement: Advertisement

    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingFullPoster = false

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    AdvertisementMediaView(
                        model: model,
                        media: advertisement.thumbnail,
                        contentMode: .fit
                    )
                    .frame(width: 112, height: 112)
                    .background(theme.subtleSurface)
                    .clipShape(RoundedRectangle(cornerRadius: MDMetrics.radius))
                    .overlay {
                        RoundedRectangle(cornerRadius: MDMetrics.radius)
                            .stroke(theme.faintSeparator, lineWidth: 1)
                    }
                    .accessibilityLabel("\(advertisement.advertiserName)缩略图")

                    VStack(alignment: .leading, spacing: 7) {
                        Text(advertisement.advertiserName)
                            .mdFont(size: 20, weight: .bold)
                            .foregroundStyle(theme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("合作推广")
                            .mdFont(.compactStrong)
                            .foregroundStyle(theme.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                MobileSectionHeading("广告介绍")
                    .padding(.top, 2)

                Text(advertisement.copyText)
                    .mdFont(.body)
                    .foregroundStyle(theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                MobileSectionHeading("广告海报")
                    .padding(.top, 2)

                ZStack(alignment: .bottomTrailing) {
                    AdvertisementMediaView(
                        model: model,
                        media: advertisement.poster,
                        contentMode: .fit
                    )
                    .frame(maxWidth: .infinity)
                    .aspectRatio(posterPreviewAspectRatio, contentMode: .fit)
                    .background(theme.subtleSurface)
                    .clipShape(RoundedRectangle(cornerRadius: MDMetrics.radius))
                    .overlay {
                        RoundedRectangle(cornerRadius: MDMetrics.radius)
                            .stroke(theme.faintSeparator, lineWidth: 1)
                    }
                    .accessibilityLabel("\(advertisement.advertiserName)广告海报")

                    Button {
                        isShowingFullPoster = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.primaryText)
                            .frame(width: 34, height: 34)
                            .background(.regularMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .accessibilityLabel("放大海报")
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 36)
        }
        .background(theme.background)
        .navigationTitle("合作推广")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .fullScreenCover(isPresented: $isShowingFullPoster) {
            AdvertisementPosterFullscreenView(model: model, media: advertisement.poster)
        }
    }

    private var posterPreviewAspectRatio: CGFloat {
        guard let poster = advertisement.poster,
              poster.pixelWidth > 0,
              poster.pixelHeight > 0 else {
            return 4 / 5
        }
        let sourceRatio = CGFloat(poster.pixelWidth) / CGFloat(poster.pixelHeight)
        return min(max(sourceRatio, 0.5), 1.8)
    }
}

@MainActor
private struct AdvertisementPosterFullscreenView: View {
    let model: AppModel
    let media: AdvertisementMedia?

    @Environment(\.dismiss) private var dismiss
    @State private var data: Data?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let data, let image = UIImage(data: data) {
                ZoomableAdvertisementScrollView(image: image)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(.white)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.black.opacity(0.58), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .padding(.trailing, 16)
            .accessibilityLabel("关闭")
        }
        .task(id: media?.storagePath) {
            guard let path = media?.storagePath else { return }
            data = await model.advertisementMediaData(storagePath: path)
        }
    }
}

private struct ZoomableAdvertisementScrollView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .black
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        ])
        context.coordinator.imageView = imageView
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }
    }
}
#endif
