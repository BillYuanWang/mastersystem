import SwiftUI

struct ContentView: View {
    var body: some View {
        MasterDanceWebView()
            .ignoresSafeArea()
    }
}

struct SettingsView: View {
    var body: some View {
        Form {
            Text("课程数据保存在 app 同级的 MD Desk Data 文件夹。")
            Text("把 macos-app 文件夹放在 Dropbox 里，同步到另一台 Mac 后双击 MD Desk 即可继续使用。")
        }
        .padding(24)
        .frame(width: 460)
    }
}
