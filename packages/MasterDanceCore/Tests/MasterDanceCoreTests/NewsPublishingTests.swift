import Foundation
import Testing
@testable import MasterDanceCore

@Suite("News publishing")
struct NewsPublishingTests {
    @Test("Articles, images, and private media remain linked")
    func articleImageLifecycle() async throws {
        let store = PreviewMasterDanceStore()
        let article = NewsArticle(
            title: "秋季课程开放报名",
            bodyText: "第一段内容。\n\n第二段内容。",
            authorName: "Master Dance",
            status: .published
        )

        let savedArticle = try await store.save(newsArticle: article)
        #expect(savedArticle.publishedAt != nil)
        #expect(savedArticle.previewText == "第一段内容。")
        #expect(savedArticle.paragraphs == ["第一段内容。", "第二段内容。"])

        let cover = NewsArticleImage(
            articleID: savedArticle.id,
            kind: .cover,
            mimeType: "image/png"
        )
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        let savedCover = try await store.save(newsArticleImage: cover, fileData: imageData)

        #expect(!savedCover.storagePath.isEmpty)
        #expect(try await store.newsMediaData(storagePath: savedCover.storagePath) == imageData)
        #expect(try await store.listNewsArticleImages(articleID: savedArticle.id) == [savedCover])

        try await store.deleteNewsArticle(id: savedArticle.id)
        #expect(try await store.listNewsArticles().isEmpty)
        #expect(try await store.listNewsArticleImages(articleID: savedArticle.id).isEmpty)
    }

    @Test("Replacing a cover keeps only one cover per article")
    func replacingCover() async throws {
        let store = PreviewMasterDanceStore()
        let article = try await store.save(
            newsArticle: NewsArticle(
                title: "演出通知",
                bodyText: "演出安排正文。",
                authorName: "教务处"
            )
        )
        let first = try await store.save(
            newsArticleImage: NewsArticleImage(articleID: article.id, kind: .cover),
            fileData: Data([1])
        )
        let second = try await store.save(
            newsArticleImage: NewsArticleImage(articleID: article.id, kind: .cover),
            fileData: Data([2])
        )

        let images = try await store.listNewsArticleImages(articleID: article.id)
        #expect(images == [second])
        #expect(images.first?.id != first.id)
    }
}
