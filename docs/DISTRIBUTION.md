# MD Desk 与 Master Dance 安装发布手册

本文件只讲“怎样把正式测试版装到员工设备”。当前推荐组合是：

- 员工 Mac：Developer ID 签名、Apple 公证的 `MD Desk.app` 压缩包。
- 员工和负责人 iPhone：App Store Connect 内部 TestFlight。
- 家长公开使用：等隐私政策、帐号删除流程和正式协议完成后，再走 App Store 审核。

## 1. 为什么这样分

macOS 的 Developer ID 版本不经过 App Store 审核。Apple 公证只检查软件签名与恶意内容，员工拿到压缩包后即可安装。以后更新时退出旧版，用新版 App 替换即可；Supabase 云端资料不会随 App 替换而消失。

iPhone 不能像 Mac 一样把 App 文件随意发给别人安装。内部 TestFlight 最适合现在的两台测试手机：不登记 UDID，更新集中，Apple 处理完成后直接在 TestFlight 点“更新”。每个测试构建可用 90 天。

## 2. 一次性的 Apple 准备

1. 在 Xcode 的 `Settings > Apple Accounts` 登录 Agentech 的 Apple Developer 帐号。
2. 确认 Xcode 显示有效的 Agentech Team，并记下 10 位 Team ID。
3. 在 `Manage Certificates` 创建或下载：
   - Apple Distribution：iPhone TestFlight 使用。
   - Developer ID Application：Mac 直接发布使用。
4. 在 Apple Developer Certificates, Identifiers & Profiles 中确认两个 App ID：
   - `com.masterdance.desk`
   - `com.masterdance.mobile`
5. 在 App Store Connect 创建 iOS App：
   - 名称：Master Dance
   - Bundle ID：`com.masterdance.mobile`
   - SKU：`masterdance-ios-2026`
   - 所属团队：Agentech
6. 为 macOS 公证创建一次钥匙串凭证：

   `APPLE_ID=你的开发者邮箱 TEAM_ID=你的TeamID ./script/setup_notary_profile.sh`

脚本会在终端安全地询问 Apple app-specific password。密码只进入 macOS 钥匙串，不会写入项目、Git 或日志。

## 3. 每次发布前

在项目根目录运行：

`./script/release_preflight.sh`

它会重新生成 Xcode 项目、校验两个 Info.plist 和隐私清单、运行全部 Swift 测试，并分别完成 macOS 与 iOS 的无签名 Release 构建。最后还会报告两种发布证书是否存在。

每次上传 TestFlight 前，`CFBundleVersion` 必须大于 Apple 已经接收过的 build。当前发布状态为：

- macOS：0.9.0 build 89，已签名、公证并生成员工安装包
- iOS：0.9.0 build 49，已上传并在 Apple 处理中
- iOS 最后确认可供测试员使用的基线：0.9.0 build 45

macOS build 89 汇总了 build 79 之后的课表、离线图片缓存、账单与收据、课程价格、成人 N 次卡、Admin SDK/MCP 和未完成课程提示。iOS build 49 汇总了 build 45 之后的本地图片缓存、成人 N 次卡余额与记录，以及相关管理员签到支持。

## 4. 生成员工 Mac 安装包

运行：

`TEAM_ID=你的TeamID ./script/release_macos.sh`

脚本会依次完成：

1. Release 归档。
2. Developer ID 签名导出。
3. 严格签名校验。
4. 提交 Apple 公证并等待结果。
5. 把公证票据装订到 App。
6. 通过 Gatekeeper 再验证。
7. 按当前源码版本输出 `dist/macos/MD-Desk-版本-构建号-macOS.zip`；当前已分发文件是 `MD-Desk-0.9.0-89-macOS.zip`。

本次安装包 SHA-256：

`3beb9ef20cc826e0984d207533706d5801b755cd84f509407129bf22b0584cc7`

员工安装：

1. 双击 ZIP 解压。
2. 把 `MD Desk.app` 拖入“应用程序”。
3. 第一次打开时确认来自你的 Agentech 开发者团队；Apple 会显示该团队的法定名称。
4. 使用自己的 Admin 帐号登录。

员工更新：

1. 退出 MD Desk。
2. 下载并解压新版本。
3. 把新版拖入“应用程序”，选择替换。
4. 重新打开。正式签名稳定后，正常更新不应反复询问旧的钥匙串授权。

## 5. 上传 iPhone 内部 TestFlight

运行：

`TEAM_ID=你的TeamID ./script/release_ios_testflight.sh`

脚本会完成正式归档、自动签名并上传 App Store Connect。当前脚本明确标记为“仅内部 TestFlight”，不会误发布到公开 App Store。

Apple 处理完成后：

1. 在 App Store Connect 的 `Users and Access` 添加员工 Apple Account，并只授予 Master Dance 所需的 App 访问。
2. 在 Master Dance 的 `TestFlight > Internal Testing` 建立内部组。
3. 把负责人和员工加入该组，并在 Apple 处理完成后选择 build 49；如果该组已开启自动分发，处理完成后会自动进入该组。
4. 两台 iPhone 从 App Store 安装 TestFlight。
5. 接受邀请，在 TestFlight 中安装 Master Dance。
6. 教务老师使用 Admin 帐号，负责人可以分别测试 Admin 和监护人帐号。

更新时只需上传更高 build。手机在 TestFlight 中点“更新”，不需要重新绑定 Supabase 家庭或课程资料。

## 6. 当前“可安装”与“公开上线”的边界

完成 Apple 登录、证书和首次 App Store Connect 记录后，本项目可以生成员工 Mac 公证版，并上传内部 TestFlight。这属于可安装、可持续更新的正式测试环境。

公开 App Store 上线是下一条流程，目前仍需至少完成：

- 可公开访问的隐私政策网址，并在 App Store Connect 填完数据收集说明。
- iPhone 内可发现的帐号删除发起流程；本项目当前只有教务端家庭删除，不等于家长帐号删除。
- 确认准备发布的家长协议已脱离内部审阅状态。
- App Store 截图、说明、支持网址、年龄分级和审核演示帐号。
- 关闭“仅内部 TestFlight”限制，上传新的 build，再提交 App Review。

这些项目不妨碍内部 TestFlight，也不妨碍 Developer ID 公证的 Mac 员工版。

## 7. 数据与设备

- Mac 和 iPhone 的正式 Release 都连接当前生产 Supabase。
- 安装包不包含学校数据库、Admin 密码或 Supabase secret key。
- App 内只有可公开使用的 Supabase publishable key；权限由 Supabase Auth 与 RLS 控制。
- 换电脑、替换 App 或升级 TestFlight 不会删除云端资料。
- Mac 公证版不需要登记员工电脑。
- TestFlight 不需要登记 iPhone UDID。

## 8. 发布失败先看哪里

- `No Developer ID Application certificate`：Xcode 尚未创建 Mac 发布证书。
- `No Accounts` 或 provisioning 错误：Xcode 没登录正确的 Agentech Team。
- 找不到 App Store Connect App：先创建 Master Dance 的 App 记录，Bundle ID 必须完全一致。
- build 已存在：把 iOS `CFBundleVersion` 加 1 后重新归档。
- 公证凭证无效：重新运行 `setup_notary_profile.sh`，使用 app-specific password。
- App Store Connect 隐私警告：检查 `PrivacyInfo.xcprivacy` 与后台隐私问卷是否一致。
