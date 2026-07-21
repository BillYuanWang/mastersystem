#if os(iOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct MobileGuardianAgreementGateView<Content: View>: View {
    let model: AppModel
    let actions: MobileMemberActionService
    let signerDisplayName: String
    let onSignOut: (() -> Void)?
    let content: Content

    @State private var state = AgreementGateState.checking
    @State private var hasChecked = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    init(
        model: AppModel,
        actions: MobileMemberActionService,
        signerDisplayName: String,
        onSignOut: (() -> Void)?,
        @ViewBuilder content: () -> Content
    ) {
        self.model = model
        self.actions = actions
        self.signerDisplayName = signerDisplayName
        self.onSignOut = onSignOut
        self.content = content()
    }

    var body: some View {
        Group {
            switch state {
            case .checking:
                checkingView
            case .ready:
                content
            case .required(let agreement):
                MobileGuardianAgreementSigningView(
                    agreement: agreement,
                    signerDisplayName: signerDisplayName,
                    actions: actions,
                    onSignOut: onSignOut,
                    onAccepted: { signaturePNG in
                        accepted(agreement, signaturePNG: signaturePNG)
                    },
                    onRefresh: { Task { await refresh(showLoading: true) } }
                )
            case .failed(let message):
                failureView(message: message)
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await refresh(showLoading: !hasChecked)
        }
    }

    private var checkingView: some View {
        let theme = MDTheme(scheme: colorScheme)
        return VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
                .tint(theme.accent)
            Text("正在检查最新协议")
                .mdFont(.compactStrong)
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }

    private func failureView(message: String) -> some View {
        let theme = MDTheme(scheme: colorScheme)
        return VStack(spacing: 16) {
            Image(systemName: "doc.badge.exclamationmark")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(theme.danger)
            Text("暂时无法检查协议")
                .mdFont(size: 20, weight: .bold)
                .foregroundStyle(theme.primaryText)
            Text(message)
                .mdFont(.body)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button("重新检查") {
                Task { await refresh(showLoading: true) }
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accent)
            if let onSignOut {
                Button("退出账号", action: onSignOut)
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
    }

    private func refresh(showLoading: Bool) async {
        if showLoading { state = .checking }
        do {
            if let agreement = try await actions.currentGuardianAgreement(),
               agreement.requiresAcceptance {
                state = .required(agreement)
            } else {
                state = .ready
            }
            hasChecked = true
        } catch {
            if showLoading || !hasChecked {
                state = .failed(error.localizedDescription)
            } else {
                model.reportBackgroundSyncFailure(error)
            }
        }
    }

    private func accepted(_ agreement: MobileGuardianAgreement, signaturePNG: Data) {
        model.applyLocalContractConsent(
            documentID: ContractDocumentID(serverID: agreement.id),
            enrollmentID: nil,
            signerKind: .guardian,
            signerDisplayName: signerDisplayName,
            signaturePNG: signaturePNG
        )
        state = .ready
    }
}

private enum AgreementGateState {
    case checking
    case ready
    case required(MobileGuardianAgreement)
    case failed(String)
}

@MainActor
private struct MobileGuardianAgreementSigningView: View {
    let agreement: MobileGuardianAgreement
    let signerDisplayName: String
    let actions: MobileMemberActionService
    let onSignOut: (() -> Void)?
    let onAccepted: (Data) -> Void
    let onRefresh: () -> Void

    @State private var hasReachedEnd = false
    @State private var signaturePNG: Data?
    @State private var signatureClearGeneration = 0
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        NavigationStack {
            GeometryReader { viewport in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        agreementHeader(theme: theme)

                        VStack(alignment: .leading, spacing: 18) {
                            MobileAgreementTextView(bodyText: agreement.bodyText)
                            MobileAgreementLegalFooter()
                            Divider()
                            Label("已阅读至协议末尾", systemImage: "checkmark.circle")
                                .mdFont(.compactStrong)
                                .foregroundStyle(theme.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(18)
                        .background(theme.raisedSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: MDMetrics.radius)
                                .stroke(theme.separator, lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: MDMetrics.radius))

                        Color.clear
                            .frame(height: 1)
                            .background {
                                GeometryReader { proxy in
                                    Color.clear.preference(
                                        key: AgreementBottomPreferenceKey.self,
                                        value: proxy.frame(in: .named(AgreementScrollSpace.name)).maxY
                                    )
                                }
                            }

                        if hasReachedEnd {
                            signatureSection(theme: theme)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: 640)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                }
                .coordinateSpace(name: AgreementScrollSpace.name)
                .onPreferenceChange(AgreementBottomPreferenceKey.self) { bottom in
                    guard !hasReachedEnd, bottom <= viewport.size.height - 24 else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        hasReachedEnd = true
                    }
                }
            }
            .background(theme.background)
            .navigationTitle("最新协议")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onSignOut {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("退出账号", action: onSignOut)
                            .disabled(isSubmitting)
                    }
                }
            }
            .overlay {
                CloudSyncOverlay(isActive: isSubmitting, label: "正在保存签名")
            }
        }
    }

    private func agreementHeader(theme: MDTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("协议已更新", systemImage: "doc.badge.clock")
                .mdFont(.compactStrong)
                .foregroundStyle(theme.accent)
            Text(agreement.title)
                .mdFont(size: 20, weight: .bold)
                .foregroundStyle(theme.primaryText)
            HStack(spacing: 8) {
                Text("版本 \(agreement.version)")
                    .mdFont(.mono)
                Text("·")
                Text("签署人：\(signerDisplayName)")
                    .mdFont(.compact)
            }
            .foregroundStyle(theme.secondaryText)
            Label(
                hasReachedEnd ? "已读到底，可以签名" : "请阅读并滚动至协议底部",
                systemImage: hasReachedEnd ? "checkmark.circle.fill" : "arrow.down.circle"
            )
            .mdFont(.compactStrong)
            .foregroundStyle(hasReachedEnd ? theme.success : theme.accent)
        }
    }

    private func signatureSection(theme: MDTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("监护人签名")
                        .mdFont(.bodyStrong)
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
                .disabled(signaturePNG == nil || isSubmitting)
            }

            MobileSignaturePad(
                signaturePNG: $signaturePNG,
                clearGeneration: signatureClearGeneration
            )
            .frame(height: 176)
            .overlay {
                RoundedRectangle(cornerRadius: MDMetrics.radius)
                    .stroke(signaturePNG == nil ? theme.separator : theme.accent, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: MDMetrics.radius))

            if let errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .mdFont(.compact)
                        .foregroundStyle(theme.danger)
                    Button("重新检查最新协议", action: onRefresh)
                        .buttonStyle(.plain)
                        .mdFont(.compactStrong)
                        .foregroundStyle(theme.accent)
                }
            }

            Button(action: submit) {
                Label("同意并继续", systemImage: "signature")
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accent)
            .disabled(signaturePNG == nil || isSubmitting)

            Text("签名将与当前协议版本、正文指纹和签署时间一并保存。")
                .mdFont(.compact)
                .foregroundStyle(theme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.bottom, 18)
        }
    }

    private func submit() {
        guard let signaturePNG else { return }
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                try await actions.acceptGuardianAgreement(
                    documentID: agreement.id,
                    displayedSHA256: agreement.sha256,
                    signaturePNG: signaturePNG
                )
                isSubmitting = false
                onAccepted(signaturePNG)
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

private enum AgreementScrollSpace {
    static let name = "guardian-current-agreement"
}

private struct AgreementBottomPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat { .greatestFiniteMagnitude }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}
#endif
