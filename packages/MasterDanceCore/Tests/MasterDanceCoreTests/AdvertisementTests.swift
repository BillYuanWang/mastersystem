import Foundation
import Testing
@testable import MasterDanceCore

@Suite("Advertisement scheduling")
struct AdvertisementTests {
    @Test("One month and one year use inclusive billing dates")
    func billingMonths() throws {
        let calendar = fixedCalendar
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 21)))
        let oneMonthEnd = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 20)))
        let oneYearEnd = try #require(calendar.date(from: DateComponents(year: 2027, month: 7, day: 20)))

        #expect(AdvertisementRules.billableMonthCount(startsOn: start, endsOn: oneMonthEnd, calendar: calendar) == 1)
        #expect(AdvertisementRules.billableMonthCount(startsOn: start, endsOn: oneYearEnd, calendar: calendar) == 12)
    }

    @Test("Only published advertisements inside their dates are active")
    func activeDateRange() throws {
        let calendar = fixedCalendar
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 21)))
        let end = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 20)))
        var advertisement = sampleAdvertisement(startsOn: start, endsOn: end)

        #expect(advertisement.isActive(on: start, calendar: calendar))
        #expect(advertisement.isActive(on: end, calendar: calendar))
        advertisement.status = .draft
        #expect(!advertisement.isActive(on: start, calendar: calendar))
    }

    @Test("Preview storage keeps both images and rejects slot overlap")
    func mediaAndSlotOverlap() async throws {
        let calendar = fixedCalendar
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 21)))
        let end = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 20)))
        let store = PreviewMasterDanceStore()
        let thumbnailData = Data([1, 2, 3])
        let posterData = Data([4, 5, 6])

        let saved = try await store.save(
            advertisement: sampleAdvertisement(startsOn: start, endsOn: end),
            thumbnailData: thumbnailData,
            posterData: posterData
        )
        #expect(saved.thumbnail?.storagePath.isEmpty == false)
        #expect(saved.poster?.storagePath.isEmpty == false)
        #expect(try await store.advertisementMediaData(storagePath: saved.thumbnail?.storagePath ?? "") == thumbnailData)
        #expect(try await store.advertisementMediaData(storagePath: saved.poster?.storagePath ?? "") == posterData)

        let overlap = sampleAdvertisement(startsOn: start, endsOn: end)
        await #expect(throws: PreviewRepositoryError.recordInUse("这个广告位在所选日期内已有其他广告。")) {
            _ = try await store.save(
                advertisement: overlap,
                thumbnailData: thumbnailData,
                posterData: posterData
            )
        }
    }

    private var fixedCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func sampleAdvertisement(startsOn: Date, endsOn: Date) -> Advertisement {
        Advertisement(
            slotNumber: 1,
            advertiserName: "Test Brand",
            copyText: "A concise advertisement.",
            thumbnail: AdvertisementMedia(
                mimeType: "image/png",
                pixelWidth: 600,
                pixelHeight: 600,
                byteCount: 3
            ),
            poster: AdvertisementMedia(
                mimeType: "image/png",
                pixelWidth: 900,
                pixelHeight: 1125,
                byteCount: 3
            ),
            startsOn: startsOn,
            endsOn: endsOn,
            status: .published
        )
    }
}
