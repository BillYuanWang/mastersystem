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
        switch self {
        case .full: "MasterDanceLogo"
        case .mark: "MasterDanceLogoMark"
        }
    }
}

struct MasterDanceLogoView: View {
    private let variant: MasterDanceLogoVariant

    init(_ variant: MasterDanceLogoVariant = .full) {
        self.variant = variant
    }

    var body: some View {
#if os(macOS)
        if let path = Bundle.main.path(forResource: variant.resourceName, ofType: "png"),
           let image = NSImage(contentsOfFile: path) {
            Image(nsImage: image)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "figure.dance")
                .resizable()
                .scaledToFit()
                .padding(8)
        }
#else
        if let path = Bundle.main.path(forResource: variant.resourceName, ofType: "png"),
           let image = UIImage(contentsOfFile: path) {
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
