#if os(iOS)
import PDFKit
import PencilKit
import SwiftUI

@MainActor
struct MobileGuardianContractRegistrationView: View {
    let session: MobileSessionModel
    let invitation: GuardianRegistrationInvitation
    let onCancel: () -> Void
    let onCompleted: () -> Void

    @State private var password = ""
    @State private var confirmation = ""
    @State private var document: GuardianRegistrationContractDocument?
    @State private var hasReachedContractEnd = false
    @State private var signaturePNG: Data?
    @State private var signatureClearGeneration = 0
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        NavigationStack {
            GeometryReader { viewport in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        identityAndPasswordSection(theme: theme)
                        contractSection(theme: theme)

                        if hasReachedContractEnd, document != nil {
                            signatureSection(theme: theme)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: 640)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                }
                .coordinateSpace(name: ContractScrollSpace.name)
                .scrollDismissesKeyboard(.interactively)
                .onPreferenceChange(ContractBottomPreferenceKey.self) { bottom in
                    guard document != nil, !hasReachedContractEnd else { return }
                    if bottom <= viewport.size.height - 24 {
                        withAnimation(.easeOut(duration: 0.2)) {
                            hasReachedContractEnd = true
                        }
                    }
                }
            }
            .background(theme.background)
            .navigationTitle("家长注册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        session.clearMessages()
                        onCancel()
                    }
                    .disabled(session.isWorking)
                }
            }
            .overlay {
                if session.isWorking, document != nil {
                    CloudSyncLoader(label: "正在安全保存")
                        .allowsHitTesting(false)
                        .transition(.scale(scale: 0.94).combined(with: .opacity))
                }
            }
        }
        .interactiveDismissDisabled(session.isWorking)
        .task(id: invitation.contract.id) {
            await loadContract()
        }
    }

    private func identityAndPasswordSection(theme: MDTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("账号信息")
                    .mdFont(.bodyStrong)
                    .foregroundStyle(theme.primaryText)
                Text("邮箱来自学校档案，注册后将作为登录账号。")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
            }

            HStack(spacing: 10) {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(theme.secondaryText)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text("登录邮箱")
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                    Text(invitation.email)
                        .mdFont(.bodyStrong)
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                Spacer(minLength: 0)
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(.horizontal, 12)
            .frame(height: 58)
            .background(theme.raisedSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
            .overlay {
                RoundedRectangle(cornerRadius: MDMetrics.radius)
                    .stroke(theme.separator, lineWidth: 1)
            }
            .accessibilityElement(children: .combine)

            MobileAuthSecureField(
                title: "创建密码",
                systemImage: "lock",
                text: $password,
                contentType: .newPassword
            )
            MobileAuthSecureField(
                title: "再次输入密码",
                systemImage: "lock.rotation",
                text: $confirmation,
                contentType: .newPassword
            )

            HStack(spacing: 6) {
                Image(systemName: passwordGuidanceIcon)
                Text(passwordGuidance)
            }
            .mdFont(.compact)
            .foregroundStyle(passwordGuidanceColor(theme: theme))
        }
    }

    @ViewBuilder
    private func contractSection(theme: MDTheme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(invitation.contract.title)
                        .mdFont(.bodyStrong)
                        .foregroundStyle(theme.primaryText)
                    Text("版本 \(invitation.contract.version)")
                        .mdFont(.mono)
                        .foregroundStyle(theme.secondaryText)
                }
                Spacer(minLength: 8)
                Label(
                    hasReachedContractEnd ? "已读到底" : "请滚动到底",
                    systemImage: hasReachedContractEnd ? "checkmark.circle.fill" : "arrow.down.circle"
                )
                .mdFont(.compactStrong)
                .foregroundStyle(hasReachedContractEnd ? theme.success : theme.accent)
            }

            if let document {
                let pdfDocument = PDFDocument(data: document.data)
                if let pdfDocument, pdfDocument.pageCount > 0 {
                    VStack(spacing: 10) {
                        ForEach(0..<pdfDocument.pageCount, id: \.self) { pageIndex in
                            MobileRegistrationPDFPageView(
                                document: pdfDocument,
                                pageIndex: pageIndex
                            )
                            .aspectRatio(pageAspectRatio(pdfDocument, index: pageIndex), contentMode: .fit)
                            .background(.white)
                            .overlay {
                                Rectangle().stroke(theme.separator, lineWidth: 1)
                            }
                            .accessibilityLabel("合同第 \(pageIndex + 1) 页，共 \(pdfDocument.pageCount) 页")
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .background {
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: ContractBottomPreferenceKey.self,
                                    value: proxy.frame(in: .named(ContractScrollSpace.name)).maxY
                                )
                            }
                        }
                } else {
                    contractFailure(theme: theme, message: "学校合同文件格式无效。")
                }
            } else if session.isWorking {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("正在安全读取合同")
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
            } else {
                contractFailure(
                    theme: theme,
                    message: session.errorMessage ?? "合同暂时无法读取。"
                )
            }
        }
    }

    private func signatureSection(theme: MDTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("监护人签名")
                        .mdFont(.bodyStrong)
                        .foregroundStyle(theme.primaryText)
                    Text("请用手指在下方签名。")
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                }
                Spacer()
                Button {
                    signaturePNG = nil
                    signatureClearGeneration += 1
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("清除签名")
                .disabled(signaturePNG == nil)
            }

            MobileSignaturePad(
                signaturePNG: $signaturePNG,
                clearGeneration: signatureClearGeneration
            )
            .frame(height: 176)
            .background(theme.raisedSurface)
            .overlay {
                RoundedRectangle(cornerRadius: MDMetrics.radius)
                    .stroke(signaturePNG == nil ? theme.separator : theme.accent, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: MDMetrics.radius))

            Button(action: submitRegistration) {
                Label("同意并注册", systemImage: "signature")
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accent)
            .disabled(!canSubmit || session.isWorking)

            Text("点击后即表示同意上方合同，并保存签名、合同版本和签署时间。")
                .mdFont(.compact)
                .foregroundStyle(theme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.bottom, 18)
        }
    }

    private func contractFailure(theme: MDTheme, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.badge.exclamationmark")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(theme.danger)
            Text(message)
                .mdFont(.compactStrong)
                .foregroundStyle(theme.primaryText)
                .multilineTextAlignment(.center)
            Button("重新读取") {
                Task { await loadContract() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
    }

    private var passwordIsAcceptable: Bool {
        password.count >= 10
            && password.contains(where: \.isLetter)
            && password.contains(where: \.isNumber)
    }

    private var canSubmit: Bool {
        document != nil
            && hasReachedContractEnd
            && signaturePNG != nil
            && passwordIsAcceptable
            && password == confirmation
    }

    private var passwordGuidance: String {
        if confirmation.isEmpty {
            return "密码至少 10 位，同时包含字母和数字"
        }
        if !passwordIsAcceptable {
            return "密码至少 10 位，同时包含字母和数字"
        }
        return password == confirmation ? "两次密码一致" : "两次输入的密码不一致"
    }

    private var passwordGuidanceIcon: String {
        if confirmation.isEmpty || !passwordIsAcceptable { return "info.circle" }
        return password == confirmation ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
    }

    private func passwordGuidanceColor(theme: MDTheme) -> Color {
        guard !confirmation.isEmpty, passwordIsAcceptable else { return theme.secondaryText }
        return password == confirmation ? theme.success : theme.danger
    }

    private func pageAspectRatio(_ document: PDFDocument, index: Int) -> CGFloat {
        guard let page = document.page(at: index) else { return 0.77 }
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.height > 0 else { return 0.77 }
        return bounds.width / bounds.height
    }

    private func loadContract() async {
        session.clearMessages()
        document = nil
        hasReachedContractEnd = false
        signaturePNG = nil
        signatureClearGeneration += 1
        document = await session.downloadGuardianRegistrationContract(invitation: invitation)
    }

    private func submitRegistration() {
        guard let document, let signaturePNG else { return }
        Task {
            if await session.registerGuardian(
                invitation: invitation,
                document: document,
                signaturePNG: signaturePNG,
                password: password,
                confirmation: confirmation
            ) {
                onCompleted()
            }
        }
    }
}

private enum ContractScrollSpace {
    static let name = "guardian-registration-contract"
}

private struct ContractBottomPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat { .greatestFiniteMagnitude }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

private struct MobileRegistrationPDFPageView: UIViewRepresentable {
    let document: PDFDocument
    let pageIndex: Int

    func makeUIView(context: Context) -> RegistrationPDFPageCanvas {
        RegistrationPDFPageCanvas(page: document.page(at: pageIndex))
    }

    func updateUIView(_ view: RegistrationPDFPageCanvas, context: Context) {
        view.page = document.page(at: pageIndex)
    }
}

@MainActor
private final class RegistrationPDFPageCanvas: UIView {
    var page: PDFPage? {
        didSet { setNeedsDisplay() }
    }

    init(page: PDFPage?) {
        self.page = page
        super.init(frame: .zero)
        isOpaque = true
        backgroundColor = .white
        contentMode = .redraw
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let page, let context = UIGraphicsGetCurrentContext() else { return }
        UIColor.white.setFill()
        context.fill(bounds)

        let pageBounds = page.bounds(for: .mediaBox)
        guard pageBounds.width > 0, pageBounds.height > 0 else { return }
        let scale = min(bounds.width / pageBounds.width, bounds.height / pageBounds.height)
        let renderedWidth = pageBounds.width * scale
        let renderedHeight = pageBounds.height * scale
        let originX = (bounds.width - renderedWidth) / 2
        let originY = (bounds.height - renderedHeight) / 2

        context.saveGState()
        context.translateBy(x: originX, y: originY + renderedHeight)
        context.scaleBy(x: scale, y: -scale)
        context.translateBy(x: -pageBounds.minX, y: -pageBounds.minY)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()
    }
}

private struct MobileSignaturePad: UIViewRepresentable {
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
