import SwiftUI
import Foundation
import ReleaseKit

@main struct ReleaseKitDemoApp:App {
    @State private var showChangelog=false
    init() {
        let key=Bundle.main.object(forInfoDictionaryKey:"ReleaseKitAppKey") as? String ?? "rk_pub_REPLACE_ME"
        let url=(Bundle.main.object(forInfoDictionaryKey:"ReleaseKitBaseURL") as? String).flatMap(URL.init(string:)) ?? URL(string:"https://releasek.it")!
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--test-offline"){URLProtocol.registerClass(DemoOfflineProtocol.self)}
        #endif
        ReleaseKit.configure(appKey:key,options:.init(baseURL:url,whatsNew:.init(isEnabled:true),comments:.init(isEnabled:true)))
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
            }.releaseKitChangelog(isPresented:$showChangelog).releaseKitWhatsNew(isEnabled:!showChangelog)
        }
    }
}

#if DEBUG
private final class DemoOfflineProtocol:URLProtocol,@unchecked Sendable {
    override class func canInit(with request:URLRequest)->Bool {request.url?.scheme=="https" || request.url?.scheme=="http"}
    override class func canonicalRequest(for request:URLRequest)->URLRequest {request}
    override func startLoading(){client?.urlProtocol(self,didFailWithError:URLError(.notConnectedToInternet))}
    override func stopLoading(){}
}
#endif
