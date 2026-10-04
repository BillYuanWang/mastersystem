import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum MasterDanceLogoVariant {
    case full
    case mark

    fileprivate var resourceName: String {
#if os(macOS)
        switch self {
        case .full: "MasterDanceMacLogo"
        case .mark: "MasterDanceMacLogoMark"
        }
#else
        switch self {
        case .full: "MasterDanceLogo"
        case .mark: "MasterDanceLogoMark"
        }
#endif
    }
}

struct MasterDanceLogoView: View {
    private let variant: MasterDanceLogoVariant

    init(_ variant: MasterDanceLogoVariant = .full) {
        self.variant = variant
    }

    var body: some View {
#if os(macOS)
        if let image = MasterDanceImageResource.image(named: variant.resourceName) {
            Image(nsImage: image)
                .renderingMode(variant == .mark ? .template : .original)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.primary)
        } else {
            Image(systemName: "figure.dance")
                .resizable()
                .scaledToFit()
                .padding(8)
        }
#else
        if let image = MasterDanceImageResource.image(named: variant.resourceName) {
            Image(uiImage: image)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "figure.dance")
                .resizable()
                .scaledToFit()
                .padding(8)
        }
#endif
    }
}

enum MasterDanceImageResource {
#if os(macOS)
    static func image(named name: String) -> NSImage? {
        candidateBundles.lazy.compactMap { bundle in
            guard let path = bundle.path(forResource: name, ofType: "png") else { return nil }
            return NSImage(contentsOfFile: path)
        }.first
    }
#else
    static func image(named name: String) -> UIImage? {
        candidateBundles.lazy.compactMap { bundle in
            guard let path = bundle.path(forResource: name, ofType: "png") else { return nil }
            return UIImage(contentsOfFile: path)
        }.first
    }
#endif

    private static var candidateBundles: [Bundle] {
        var bundles = [Bundle.main]
#if SWIFT_PACKAGE
        bundles.append(.module)
#endif
        return bundles
    }
}
