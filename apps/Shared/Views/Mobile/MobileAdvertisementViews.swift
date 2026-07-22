#if os(iOS)
import MasterDanceCore
import SwiftUI

@MainActor
struct MobileAdvertisementSection: View {
    let model: AppModel

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        let advertisements = model.activeAdvertisements()
        if !advertisements.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Divider()
                    .padding(.bottom, 4)

                HStack(alignment: .firstTextBaseline) {
                    Text("广告")
                        .mdFont(.bodyStrong)
                        .foregroundStyle(theme.primaryText)
                    Spacer()
                    Text(advertisements.count > 1 ? "合作推广 · \(advertisements.count)" : "合作推广")
                        .mdFont(.mono)
                        .foregroundStyle(theme.secondaryText)
                }

                TabView {
                    ForEach(advertisements) { advertisement in
                        MobileAdvertisementCard(model: model, advertisement: advertisement)
                            .padding(.bottom, advertisements.count > 1 ? 16 : 0)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: advertisements.count > 1 ? .automatic : .never))
                .frame(height: advertisements.count > 1 ? 126 : 106)

                Text("广告位有限，合作投放请联系佳美舞蹈教务老师。")
                    .mdFont(.compact)
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.top, 2)
        }
    }
}

@MainActor
private struct MobileAdvertisementCard: View {
    let model: AppModel
    let advertisement: Advertisement

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        NavigationLink {
            MobileAdvertisementDetailView(model: model, advertisement: advertisement)
        } label: {
            HStack(spacing: 12) {
                AdvertisementMediaView(
                    model: model,
                    media: advertisement.thumbnail,
                    contentMode: .fit
                )
                .frame(width: 82, height: 82)
                .background(theme.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: MDMetrics.radius))
                .overlay {
                    RoundedRectangle(cornerRadius: MDMetrics.radius)
                        .stroke(theme.faintSeparator, lineWidth: 1)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(advertisement.advertiserName)
                            .mdFont(.bodyStrong)
                            .foregroundStyle(theme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)

                        Text("推广")
                            .mdFont(size: 10, weight: .semibold, design: .monospaced)
                            .foregroundStyle(theme.secondaryText)
                            .padding(.horizontal, 5)
                            .frame(height: 19)
                            .overlay {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(theme.separator, lineWidth: 1)
                            }
                    }

                    Text(advertisement.copyText)
                        .mdFont(.compact)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(2)

                    Text("查看广告详情")
                        .mdFont(.compactStrong)
                        .foregroundStyle(theme.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(10)
            .background(theme.raisedSurface, in: RoundedRectangle(cornerRadius: MDMetrics.radius))
            .overlay {
                RoundedRectangle(cornerRadius: MDMetrics.radius)
                    .stroke(theme.faintSeparator, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("推广，\(advertisement.advertiserName)，\(advertisement.copyText)")
        .accessibilityHint("查看完整广告海报")
    }
}

@MainActor
private struct MobileAdvertisementDetailView: View {
    let model: AppModel
    let advertisement: Advertisement

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = MDTheme(scheme: colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    AdvertisementMediaView(
                        model: model,
                        media: advertisement.thumbnail,
                        contentMode: .fit
                    )
                    .frame(width: 112, height: 112)
                    .background(theme.subtleSurface)
                    .clipShape(RoundedRectangle(cornerRadius: MDMetrics.radius))
                    .overlay {
                        RoundedRectangle(cornerRadius: MDMetrics.radius)
                            .stroke(theme.faintSeparator, lineWidth: 1)
                    }
                    .accessibilityLabel("\(advertisement.advertiserName)缩略图")

                    VStack(alignment: .leading, spacing: 7) {
                        Text(advertisement.advertiserName)
                            .mdFont(size: 20, weight: .bold)
                            .foregroundStyle(theme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("合作推广")
                            .mdFont(.compactStrong)
                            .foregroundStyle(theme.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                MobileSectionHeading("广告介绍")
                    .padding(.top, 2)

                Text(advertisement.copyText)
                    .mdFont(.body)
                    .foregroundStyle(theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                MobileSectionHeading("广告海报")
                    .padding(.top, 2)

                AdvertisementMediaView(
                    model: model,
                    media: advertisement.poster,
                    contentMode: .fit
                )
                .frame(maxWidth: .infinity)
                .aspectRatio(posterAspectRatio, contentMode: .fit)
                .background(theme.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: MDMetrics.radius))
                .overlay {
                    RoundedRectangle(cornerRadius: MDMetrics.radius)
                        .stroke(theme.faintSeparator, lineWidth: 1)
                }
                .accessibilityLabel("\(advertisement.advertiserName)广告海报")
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 36)
        }
        .background(theme.background)
        .navigationTitle("合作推广")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var posterAspectRatio: CGFloat {
        guard let poster = advertisement.poster,
              poster.pixelWidth > 0,
              poster.pixelHeight > 0 else {
            return 4 / 5
        }
        return CGFloat(poster.pixelWidth) / CGFloat(poster.pixelHeight)
    }
}
#endif
