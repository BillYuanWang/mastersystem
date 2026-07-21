#if os(iOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct MobileNewsRow: View {
    let model: AppModel
    let article: NewsArticle

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        HStack(spacing: 12) {
            NewsMediaView(model: model, image: model.newsCover(for: article.id))
                .frame(width: 94, height: 72)
                .background(theme.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: MDMetrics.radius))

            VStack(alignment: .leading, spacing: 5) {
                Text(article.title)
                    .mdFont(.bodyStrong)
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(2)

                Text(article.previewText + (article.previewText.isEmpty ? "" : " …"))
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(2)

                if let date = article.publishedAt {
                    Text(date.mdChineseFormatted(.dateTime.year().month().day()))
                        .mdFont(.mono)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .mdFont(.compactStrong)
                .foregroundStyle(theme.secondaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

@MainActor
struct MobileNewsDetailView: View {
    let model: AppModel
    let article: NewsArticle

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text(article.title)
                    .mdFont(size: 25, weight: .bold)
                    .foregroundStyle(theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Text(article.authorName)
                        .mdFont(.compactStrong)
                    if let date = article.publishedAt {
                        Text("·")
                            .foregroundStyle(theme.secondaryText)
                        Text(date.mdChineseFormatted(.dateTime.year().month().day()))
                            .mdFont(.mono)
                            .foregroundStyle(theme.secondaryText)
                    }
                }

                if let cover = model.newsCover(for: article.id) {
                    NewsMediaView(model: model, image: cover, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .background(theme.subtleSurface)
                        .clipShape(RoundedRectangle(cornerRadius: MDMetrics.radius))
                }

                ForEach(Array(article.paragraphs.enumerated()), id: \.offset) { index, paragraph in
                    Text(paragraph)
                        .mdFont(.body)
                        .foregroundStyle(theme.primaryText)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(images(afterParagraph: index)) { image in
                        articleImage(image, theme: theme)
                    }
                }

                ForEach(unplacedImages) { image in
                    articleImage(image, theme: theme)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 36)
        }
        .background(theme.background)
        .navigationTitle("新闻")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var bodyImages: [NewsArticleImage] {
        model.newsImages(for: article.id).filter { $0.kind == .body }
    }

    private var unplacedImages: [NewsArticleImage] {
        bodyImages.filter { image in
            guard let placement = image.placementAfterParagraph else { return true }
            return placement >= article.paragraphs.count
        }
    }

    private func images(afterParagraph index: Int) -> [NewsArticleImage] {
        bodyImages.filter { $0.placementAfterParagraph == index }
    }

    private func articleImage(_ image: NewsArticleImage, theme: MDTheme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            NewsMediaView(model: model, image: image, contentMode: .fit)
                .frame(maxWidth: .infinity, minHeight: 160)
                .background(theme.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: MDMetrics.radius))
            if let caption = image.caption, !caption.isEmpty {
                Text(caption)
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}
#endif
