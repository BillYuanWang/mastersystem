import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct MasterDanceLogoView: View {
    var body: some View {
#if os(macOS)
        if let path = Bundle.main.path(forResource: "MasterDanceLogo", ofType: "png"),
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
        if let path = Bundle.main.path(forResource: "MasterDanceLogo", ofType: "png"),
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
