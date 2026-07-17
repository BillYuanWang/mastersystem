import Foundation

enum AppPaths {
    static var webIndexURL: URL {
        guard let resourceURL = Bundle.main.resourceURL else {
            fatalError("Missing app resources.")
        }
        return resourceURL
            .appendingPathComponent("Web", isDirectory: true)
            .appendingPathComponent("index.html")
    }

    static var dataDirectoryURL: URL {
        let appFolderURL = Bundle.main.bundleURL.deletingLastPathComponent()
        let portableURL = appFolderURL.appendingPathComponent("MD Desk Data", isDirectory: true)
        if ensureDirectory(portableURL) {
            return portableURL
        }

        let fallbackURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MD Desk", isDirectory: true)
        _ = ensureDirectory(fallbackURL)
        return fallbackURL
    }

    static var coursesCSVURL: URL {
        dataDirectoryURL.appendingPathComponent("courses.csv")
    }

    static var bundledCoursesCSVURL: URL? {
        Bundle.main.resourceURL?
            .appendingPathComponent("Web", isDirectory: true)
            .appendingPathComponent("courses.csv")
    }

    private static func ensureDirectory(_ url: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return true
        } catch {
            return false
        }
    }
}
