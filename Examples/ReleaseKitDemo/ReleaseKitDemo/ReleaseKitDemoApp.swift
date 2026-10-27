import SwiftUI
import ReleaseKit

@main struct ReleaseKitDemoApp:App {
    init() {
        let key=Bundle.main.object(forInfoDictionaryKey:"ReleaseKitAppKey") as? String ?? "rk_pub_REPLACE_ME"
        let url=(Bundle.main.object(forInfoDictionaryKey:"ReleaseKitBaseURL") as? String).flatMap(URL.init(string:)) ?? URL(string:"https://releasek.it")!
        #if DEBUG
        let options=ReleaseKit.Options(baseURL:url,whatsNew:.init(debugAlwaysShow:true))
        #else
        let options=ReleaseKit.Options(baseURL:url)
        #endif
        ReleaseKit.configure(appKey:key,options:options)
    }
    var body:some Scene {WindowGroup {NavigationStack {List {Section("ReleaseKit") {ReleaseKitSettingsLink()};Section("Debug") {Button("Reset local state") {ReleaseKit.resetLocalState()};Button("Show What's New") {Task {await ReleaseKit.presentWhatsNewIfNeeded()}}}}.navigationTitle("ReleaseKit Demo")}.releaseKitWhatsNew()}}
}
