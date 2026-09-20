import Foundation
import MasterDanceCore
import Testing
#if os(macOS)
import AppKit
#endif
@testable import MasterDanceAdmin

@Suite("Billing schedule snapshots")
struct BillingScheduleSnapshotTests {
    @Test("RPC payload preserves actual sessions as structured JSON")
    func snapshotPayloadRoundTrip() throws {
        let snapshot = makeSnapshot()
        let item = BillingInvoiceLineItem(invoiceID: BillingInvoiceID(), kind: .tuition,
            title: "Dance", scheduleSnapshot: snapshot, quantity: 17, unitAmountCents: 3500, amountCents: 59500)
        let data = try JSONEncoder().encode(BillingInvoiceItemPayload(item))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let stored = try #require(object["schedule_snapshot"] as? [String: Any])
        #expect(stored["version"] as? Int == 1)
        #expect(stored["registrationMode"] as? String == "full_term")
        #expect((stored["sessions"] as? [Any])?.count == 17)
        let decoded = try JSONDecoder().decode(BillingScheduleSnapshot.self, from: JSONSerialization.data(withJSONObject: stored))
        #expect(decoded == snapshot)
    }

    @Test("Both language variants show all dates and the changed weekday and room")
    func bilingualActualDates() {
        let snapshot = makeSnapshot()
        let chinese = BillingSchedulePresentation.detail(snapshot, english: false)
        let english = BillingSchedulePresentation.detail(snapshot, english: true)
        for text in [chinese, english] {
            #expect(text.contains("2026/08/23"))
            #expect(text.contains("2026/09/12"))
            #expect(text.contains("2026/12/19"))
            #expect(text.contains("Large room"))
            #expect(text.contains("Small room"))
            #expect(!text.contains("2026/11/28"))
        }
        #expect(english.contains("Sun 11:00"))
        #expect(english.contains("Sat 11:00"))
        #expect(english.contains("3 sessions"))
        #expect(english.contains("14 sessions"))
    }

    #if os(macOS)
    @Test("Long real-date receipt details produce full-height bilingual PNGs")
    @MainActor
    func rendersLongSchedule() throws {
        let snapshot = makeSnapshot()
        let items = (1...3).map { index in
            ReceiptLineItem(kind: .tuition, section: .fullTerm, title: "中国舞表演课 \(index)",
                englishTitle: "Chinese Dance Performance \(index)", amount: 595, learnerName: "Test Learner",
                detail: BillingSchedulePresentation.detail(snapshot, english: false),
                englishDetail: BillingSchedulePresentation.detail(snapshot, english: true))
        }
        for language in [BillingArtifactLanguage.bilingual, .english] {
            let document = ReceiptDocument(language: language, kind: .invoice, receiptNumber: "QA-BUILD90",
                version: 1, termLabel: "2026 Fall", issuedOn: snapshot.sessions[0].startsAt,
                guardianName: "Test Guardian", guardianEmail: "test@example.com", guardianPhone: nil,
                learnerName: "Test Learner", items: items, note: "Layout verification only")
            let data = try ReceiptPNGRenderer.render(document)
            let bitmap = try #require(NSBitmapImageRep(data: data))
            #expect(bitmap.pixelsWide == 880)
            #expect(bitmap.pixelsHigh > 1520)
            if let root = ProcessInfo.processInfo.environment["MD_SCHEDULE_RECEIPT_QA_DIR"] {
                try data.write(to: URL(fileURLWithPath: root).appendingPathComponent("build90-\(language.rawValue).png"))
            }
        }
    }
    #endif

    private func makeSnapshot() -> BillingScheduleSnapshot {
        let dates = ["08-23", "08-30", "09-06", "09-12", "09-19", "09-26", "10-03", "10-10", "10-17", "10-24", "10-31", "11-07", "11-14", "11-21", "12-05", "12-12", "12-19"]
        let calendar = Calendar.masterDance
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let courseID = CourseID()
        return BillingScheduleSnapshot(courseName: "Chinese Dance Performance", studentName: "Test Learner",
            registrationMode: .fullTerm, timeZoneIdentifier: calendar.timeZone.identifier,
            sessions: dates.enumerated().map { index, day in
                let start = formatter.date(from: "2026-\(day) 11:00")!
                let session = ClassSession(courseID: courseID, startsAt: start, endsAt: start.addingTimeInterval(3600), status: .scheduled)
                return .init(session: session, room: index < 3 ? "Large room" : "Small room", instructor: "Instructor")
            })
    }
}
