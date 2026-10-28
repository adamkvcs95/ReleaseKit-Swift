import SwiftUI
import ReleaseKit

@main struct ReleaseKitDemoApp:App {
    @State private var showChangelog=false
    init() {
        let key=Bundle.main.object(forInfoDictionaryKey:"ReleaseKitAppKey") as? String ?? "rk_pub_REPLACE_ME"
        let url=(Bundle.main.object(forInfoDictionaryKey:"ReleaseKitBaseURL") as? String).flatMap(URL.init(string:)) ?? URL(string:"https://releasek.it")!
        ReleaseKit.configure(appKey:key,options:.init(baseURL:url,whatsNew:.init(isEnabled:false),comments:.init(isEnabled:false)))
        #if DEBUG
        _showChangelog=State(initialValue:ProcessInfo.processInfo.arguments.contains("--show-changelog"))
        #endif
    }
    var body:some Scene {
        WindowGroup {
            NavigationStack {
                VStack(spacing:20) {
                    Image(systemName:"sparkles").font(.system(size:44)).foregroundStyle(.tint)
                    Text("ReleaseKit").font(.largeTitle.bold())
                    Text("A native changelog for your app.").foregroundStyle(.secondary)
                    Button("Open changelog"){showChangelog=true}.buttonStyle(.borderedProminent).accessibilityIdentifier("releasekit.demo.open")
                }.padding().navigationTitle("Demo")
            }.releaseKitChangelog(isPresented:$showChangelog)
        }
    }
}
