#if os(iOS)
import Foundation
import PencilKit
import SwiftUI

struct MobileAgreementTextView: View {
    let bodyText: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        LazyVStack(alignment: .leading, spacing: 14) {
            ForEach(paragraphs) { paragraph in
                Text(paragraph.text)
                    .mdFont(paragraph.isHeading ? .bodyStrong : .body)
                    .foregroundStyle(theme.primaryText)
                    .lineSpacing(paragraph.isHeading ? 1 : 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var paragraphs: [AgreementParagraph] {
        bodyText
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { index, text in
                AgreementParagraph(
                    id: index,
                    text: text,
                    isHeading: isHeading(text)
                )
            }
    }

    private func isHeading(_ text: String) -> Bool {
        guard text.count <= 48 else { return false }
        if text == "重要提示" { return true }
        return text.range(of: #"^\d+[\.、]\s*"#, options: .regularExpression) != nil
    }
}

private struct AgreementParagraph: Identifiable {
    let id: Int
    let text: String
    let isHeading: Bool
}

struct MobileSignaturePad: UIViewRepresentable {
    @Binding var signaturePNG: Data?
    let clearGeneration: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvas.backgroundColor = .white
        canvas.isOpaque = true
        canvas.isScrollEnabled = false
        canvas.alwaysBounceHorizontal = false
        canvas.alwaysBounceVertical = false
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        canvas.tool = PKInkingTool(.pen, color: .black, width: 3)
        if context.coordinator.clearGeneration != clearGeneration {
            context.coordinator.clearGeneration = clearGeneration
            canvas.drawing = PKDrawing()
        }
    }

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: MobileSignaturePad
        var clearGeneration: Int

        init(parent: MobileSignaturePad) {
            self.parent = parent
            clearGeneration = parent.clearGeneration
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let drawing = canvasView.drawing
            guard !drawing.strokes.isEmpty, !drawing.bounds.isEmpty else {
                parent.signaturePNG = nil
                return
            }
            let imageBounds = drawing.bounds.insetBy(dx: -12, dy: -12)
            parent.signaturePNG = drawing.image(from: imageBounds, scale: 2).pngData()
        }
    }
}
#endif
