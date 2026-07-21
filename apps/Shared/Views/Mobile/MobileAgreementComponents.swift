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

struct MobileAgreementLegalFooter: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        VStack(alignment: .leading, spacing: 10) {
            Label("合同主体 / CONTRACTING ENTITY", systemImage: "building.columns.fill")
                .mdFont(.compactStrong)
                .foregroundStyle(theme.secondaryText)

            VStack(alignment: .leading, spacing: 3) {
                Text("Starton EDU Irvine, Inc.")
                    .mdFont(.bodyStrong)
                    .foregroundStyle(theme.primaryText)
                Text("Master Dance · 尔湾佳美舞蹈")
                    .mdFont(.compactStrong)
                    .foregroundStyle(theme.primaryText)
            }

            Divider()

            Text("本协议由 Starton EDU Irvine, Inc. 运营的 Master Dance（尔湾佳美舞蹈）发布并执行。在适用法律允许的范围内，Master Dance 保留对本协议及相关课程、教务安排的最终解释权；本条不限制任何依法不得放弃或排除的权利。")
                .mdFont(.compact)
                .foregroundStyle(theme.secondaryText)
                .lineSpacing(4)

            Text("This agreement is issued and administered by Master Dance, operated by Starton EDU Irvine, Inc. To the fullest extent permitted by applicable law, Master Dance reserves the final right to interpret this agreement and related course and administrative matters. Nothing in this statement limits any non-waivable rights under applicable law.")
                .mdFont(.compact)
                .foregroundStyle(theme.secondaryText)
                .lineSpacing(3)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
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
