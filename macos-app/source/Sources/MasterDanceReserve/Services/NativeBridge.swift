import Foundation
import WebKit

final class NativeBridge: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    static let messageHandlerName = "masterDance"

    private weak var webView: WKWebView?

    func attach(webView: WKWebView) {
        self.webView = webView
        ensureSeedCSVExists()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard
            message.name == Self.messageHandlerName,
            let body = message.body as? [String: Any],
            let id = body["id"] as? String,
            let action = body["action"] as? String
        else {
            return
        }

        switch action {
        case "loadCsv":
            loadCSV(requestID: id)
        case "saveCsv":
            saveCSV(requestID: id, csv: body["csv"] as? String)
        default:
            reply(requestID: id, ok: false, payload: ["error": "Unknown action: \(action)"])
        }
    }

    private func ensureSeedCSVExists() {
        let csvURL = AppPaths.coursesCSVURL
        guard !FileManager.default.fileExists(atPath: csvURL.path) else {
            return
        }

        do {
            if let bundledURL = AppPaths.bundledCoursesCSVURL,
               FileManager.default.fileExists(atPath: bundledURL.path) {
                try FileManager.default.copyItem(at: bundledURL, to: csvURL)
            } else {
                try "课程ID,课程名称,课程类型,组课私课,老师,年龄段,星期,教室,开始时间,结束时间,起始周,结束周,停课日期,单期价格,按期价格,报名学生,备注,创建时间,更新时间\n"
                    .write(to: csvURL, atomically: true, encoding: .utf8)
            }
        } catch {
            NSLog("Failed to seed courses.csv: \(error.localizedDescription)")
        }
    }

    private func loadCSV(requestID: String) {
        do {
            ensureSeedCSVExists()
            let csv = try String(contentsOf: AppPaths.coursesCSVURL, encoding: .utf8)
            reply(
                requestID: requestID,
                ok: true,
                payload: [
                    "csv": csv,
                    "fileName": AppPaths.coursesCSVURL.lastPathComponent,
                    "path": AppPaths.coursesCSVURL.path
                ]
            )
        } catch {
            reply(requestID: requestID, ok: false, payload: ["error": error.localizedDescription])
        }
    }

    private func saveCSV(requestID: String, csv: String?) {
        guard let csv else {
            reply(requestID: requestID, ok: false, payload: ["error": "Missing CSV body."])
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: AppPaths.dataDirectoryURL,
                withIntermediateDirectories: true
            )
            try csv.write(to: AppPaths.coursesCSVURL, atomically: true, encoding: .utf8)
            reply(
                requestID: requestID,
                ok: true,
                payload: [
                    "fileName": AppPaths.coursesCSVURL.lastPathComponent,
                    "path": AppPaths.coursesCSVURL.path
                ]
            )
        } catch {
            reply(requestID: requestID, ok: false, payload: ["error": error.localizedDescription])
        }
    }

    private func reply(requestID: String, ok: Bool, payload: [String: Any]) {
        var response = payload
        response["id"] = requestID
        response["ok"] = ok

        guard
            let data = try? JSONSerialization.data(withJSONObject: response),
            let json = String(data: data, encoding: .utf8)
        else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.webView?.evaluateJavaScript("window.masterDanceNative?.receive(\(json));")
        }
    }
}
