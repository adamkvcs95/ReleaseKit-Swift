#if canImport(UIKit) && canImport(SwiftUI)
import Foundation
import SwiftUI
import UIKit
import Security
import Observation
import OSLog
import ReleaseKitCore

@MainActor public enum ReleaseKit {
    public struct Options {
        public struct WhatsNew {
            public var isEnabled:Bool; public var treatFirstLaunchAsUpdate:()->Bool; public var presentationDelay:Duration; public var debugAlwaysShow:Bool
            public init(isEnabled:Bool=true,treatFirstLaunchAsUpdate:@escaping ()->Bool={false},presentationDelay:Duration = .seconds(1),debugAlwaysShow:Bool=false) {self.isEnabled=isEnabled;self.treatFirstLaunchAsUpdate=treatFirstLaunchAsUpdate;self.presentationDelay=presentationDelay;self.debugAlwaysShow=debugAlwaysShow}
        }
        public struct Comments {public var isEnabled:Bool;public init(isEnabled:Bool=true){self.isEnabled=isEnabled}}
        public enum AppAttest {case automatic,disabled}
        public enum LogLevel {case off,error,warning,debug}
        public var baseURL:URL;public var whatsNew:WhatsNew;public var comments:Comments;public var appAttest:AppAttest;public var logLevel:LogLevel
        public init(baseURL:URL=URL(string:"https://releasek.it")!,whatsNew:WhatsNew = .init(),comments:Comments = .init(),appAttest:AppAttest = .automatic,logLevel:LogLevel = .warning){self.baseURL=baseURL;self.whatsNew=whatsNew;self.comments=comments;self.appAttest=appAttest;self.logLevel=logLevel}
    }
    static var runtime:Runtime?
    public static func configure(appKey:String,options:Options = .init()) {
        guard let identity=KeychainIdentity.loadOrCreate() else {Logger(subsystem:"it.releasek.sdk",category:"identity").error("Unable to access the anonymous identity.");runtime=nil;return}
        let instance=Runtime(appKey:appKey,identity:identity,options:options);runtime=instance
        Task {await instance.loadConfig()}
    }
    public static var webChangelogURL:URL? {runtime?.config?.app.changelogUrl}
    public static var ideasURL:URL? {runtime?.config?.app.ideasUrl}
    public static func resetLocalState() {
        #if DEBUG
        runtime?.reset()
        #endif
    }
    public static func presentWhatsNewIfNeeded() async {
        guard let runtime,let release=await runtime.prepareWhatsNew() else {return}
        guard let scene=UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).first(where:{$0.activationState == .foregroundActive}),let window=scene.windows.first(where:{$0.isKeyWindow}),let root=window.rootViewController else {return}
        var top=root;while let presented=top.presentedViewController {top=presented}
        guard !(top is UIAlertController) else {return}
        let controller=UIHostingController(rootView:WhatsNewSheet(release:release,runtime:runtime,onPresent:{runtime.markPresented(release.version)}))
        if let sheet=controller.sheetPresentationController {sheet.detents=[.medium(),.large()];sheet.prefersGrabberVisible=true}
        top.present(controller,animated:true)
    }
}

private enum KeychainIdentity {
    static func loadOrCreate()->String? {
        let base:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"it.releasek.sdk",kSecAttrAccount as String:"anonId",kSecAttrSynchronizable as String:false]
        var query=base;query[kSecReturnData as String]=true;query[kSecMatchLimit as String]=kSecMatchLimitOne
        var result:CFTypeRef?
        let status=SecItemCopyMatching(query as CFDictionary,&result)
        if status == errSecSuccess,let data=result as? Data,let id=String(data:data,encoding:.utf8),UUID(uuidString:id) != nil{return id.lowercased()}
        guard status == errSecItemNotFound else {Logger(subsystem:"it.releasek.sdk",category:"identity").error("Keychain read failed: \(status)");return nil}
        let id=UUID().uuidString.lowercased();var insert=base;insert[kSecValueData as String]=Data(id.utf8);insert[kSecAttrAccessible as String]=kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let add=SecItemAdd(insert as CFDictionary,nil)
        if add == errSecDuplicateItem{return loadOrCreate()}
        if add != errSecSuccess {Logger(subsystem:"it.releasek.sdk",category:"identity").error("Keychain write failed: \(add)")}
        return add == errSecSuccess ? id : nil
    }
}

@Observable @MainActor final class Runtime {
    let options:ReleaseKit.Options
    private let client:APIClient
    private var state:LocalState
    private var fetching=false
    var config:AppConfig?
    init(appKey:String,identity:String,options:ReleaseKit.Options) {
        self.options=options;client=APIClient(baseURL:options.baseURL,appKey:appKey,anonID:identity);state=Self.loadState()
    }
    private static var stateURL:URL? {FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask).first?.appending(path:"ReleaseKit/state.json")}
    private static func loadState()->LocalState {guard let url=stateURL,let data=try? Data(contentsOf:url),let value=try? JSONDecoder().decode(LocalState.self,from:data) else{return LocalState()};return value}
    private func save(){guard let url=Self.stateURL,let data=try? JSONEncoder().encode(state) else{return};do{try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true);try data.write(to:url,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])}catch{}}
    func reset(){state=LocalState();save()}
    func loadConfig() async {do {config=try await client.config()} catch {if options.logLevel != .off {Logger(subsystem:"it.releasek.sdk",category:"network").warning("Unable to load configuration.")}}}
    func releases() async throws->[Release] {try await client.releases().items}
    func changelog(cursor:String?=nil) async throws->ReleasesResponse {
        if cursor == nil {config=try await client.config()}
        return try await client.releases(cursor:cursor)
    }
    func vote(type:String,id:String,value:Int) async throws -> VoteResult {try await client.vote(targetType:type,targetId:id,value:value)}
    func comments(version:String) async throws -> [Comment] {try await client.comments(version:version).items}
    func acceptGuidelines() async throws {try await client.acceptGuidelines();await loadConfig()}
    func addComment(version:String,body:String,parentId:String?=nil) async throws {let _=try await client.addComment(version:version,body:body,parentId:parentId)}
    func report(id:String,reason:String) async throws {try await client.report(commentId:id,reason:reason)}
    func block(id:String) async throws {try await client.block(commentId:id)}
    func prepareWhatsNew() async -> Release? {
        guard options.whatsNew.isEnabled,!fetching,let version=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String else{return nil}
        fetching=true;defer{fetching=false}
        let decision=WhatsNewDecider.prepare(version:version,state:&state,treatFirstLaunchAsUpdate:options.whatsNew.treatFirstLaunchAsUpdate(),debugAlwaysShow:options.whatsNew.debugAlwaysShow);save()
        guard decision == .fetch else{return nil}
        do {let response=try await client.whatsNew(version:version);guard let responseState=response.releaseState else{return nil};let decision=WhatsNewDecider.resolve(version:version,response:responseState,state:&state,now:Date());save();guard decision == .show,let release=response.release else{return nil};try await Task.sleep(for:options.whatsNew.presentationDelay);return release}catch{if options.logLevel != .off {Logger(subsystem:"it.releasek.sdk",category:"network").warning("Unable to load release notes.")};return nil}
    }
    func markPresented(_ version:String){WhatsNewDecider.markPresented(version:version,state:&state);save();Task{try? await client.event(type:"sheet_impression",version:version)}}
}

private struct WhatsNewModifier:ViewModifier {
    @Environment(\.scenePhase) private var phase
    @State private var release:Release?
    let isEnabled:Bool;let onPresent:((String)->Void)?;let onDismiss:(()->Void)?
    func body(content:Content)->some View {
        content.task{await attempt()}.onChange(of:phase){_,newValue in if newValue == .active {Task{await attempt()}}}.sheet(item:$release,onDismiss:onDismiss){item in
            if let runtime=ReleaseKit.runtime {WhatsNewSheet(release:item,runtime:runtime,onPresent:{runtime.markPresented(item.version);onPresent?(item.version)}).presentationDetents([.medium,.large]).presentationDragIndicator(.visible)}
        }
    }
    @MainActor private func attempt() async {guard isEnabled,release == nil,let runtime=ReleaseKit.runtime else{return};release=await runtime.prepareWhatsNew()}
}
public extension View {
    @MainActor func releaseKitWhatsNew(isEnabled:Bool=true,onPresent:((String)->Void)?=nil,onDismiss:(()->Void)?=nil)->some View {modifier(WhatsNewModifier(isEnabled:isEnabled,onPresent:onPresent,onDismiss:onDismiss))}
}

private struct WhatsNewSheet:View {
    @Environment(\.dismiss) private var dismiss
    @State private var didPresent=false
    let release:Release;let runtime:Runtime;let onPresent:()->Void
    var body:some View {NavigationStack {VStack(alignment:.leading,spacing:16){Text("What's New",bundle:.module).font(.title2.bold());Text(release.version).font(.subheadline).foregroundStyle(.secondary);ScrollView {Text(release.notes).frame(maxWidth:.infinity,alignment:.leading).textSelection(.enabled)};if runtime.config?.features.votes == true {VoteControl(runtime:runtime,type:"release",id:release.id,up:release.upCount,down:release.downCount,selected:release.myVote)};Button(String(localized:"Continue",bundle:.module)){dismiss()}.buttonStyle(.borderedProminent).frame(maxWidth:.infinity);NavigationLink(String(localized:"All updates",bundle:.module)){ReleaseKitChangelogView()}.frame(maxWidth:.infinity)}.padding().toolbar{ToolbarItem(placement:.topBarTrailing){Menu {if let email=runtime.config?.developer.contactEmail,let url=URL(string:"mailto:\(email)"){Link(String(localized:"Contact developer",bundle:.module),destination:url)};if let url=runtime.config?.legal.guidelinesUrl {Link(String(localized:"Community guidelines",bundle:.module),destination:url)}}label:{Image(systemName:"ellipsis.circle").accessibilityLabel("More")}}}.onAppear{if !didPresent {didPresent=true;onPresent()}}}}
}

/// Native release history with in-app up/down votes. Embed in a NavigationStack,
/// or use `.releaseKitChangelog(isPresented:)` for a self-contained sheet.
@MainActor public struct ReleaseKitChangelogView:View {
    @State private var releases:[Release]=[]
    @State private var isLoading=true
    @State private var failed=false
    @State private var loadingMore=false
    @State private var nextCursor:String?
    public init(){}
    public var body:some View {
        Group {
            if ReleaseKit.runtime == nil {
                ContentUnavailableView(String(localized:"ReleaseKit is not configured",bundle:.module),systemImage:"gearshape",description:Text("Configure ReleaseKit with your app key before opening the changelog.",bundle:.module))
            } else if isLoading {
                ProgressView(String(localized:"Loading updates…",bundle:.module)).frame(maxWidth:.infinity,maxHeight:.infinity)
            } else if releases.isEmpty {
                ContentUnavailableView {
                    Label(String(localized:failed ? "Unable to load updates":"No updates yet",bundle:.module),systemImage:failed ? "wifi.exclamationmark":"sparkles")
                } description:{
                    Text(failed ? String(localized:"Check your connection and try again.",bundle:.module):String(localized:"New releases will appear here.",bundle:.module))
                } actions:{Button(String(localized:"Try again",bundle:.module)){Task{await refresh()}}}
            } else if let runtime=ReleaseKit.runtime {
                ScrollView {
                    LazyVStack(alignment:.leading,spacing:18) {
                        if let config=runtime.config {
                            HStack(spacing:12) {
                                if let icon=config.app.iconUrl {AsyncImage(url:icon){image in image.resizable().scaledToFill()}placeholder:{Color.secondary.opacity(0.1)}.frame(width:48,height:48).clipShape(RoundedRectangle(cornerRadius:12)).accessibilityHidden(true)}
                                VStack(alignment:.leading,spacing:4){Text(config.app.name).font(.headline);Text("Latest updates and improvements",bundle:.module).font(.subheadline).foregroundStyle(.secondary)}
                            }.padding(.vertical,8)
                        }
                        if failed {HStack {Text("Could not refresh updates.",bundle:.module).font(.caption);Spacer();Button(String(localized:"Try again",bundle:.module)){Task{await refresh()}}}.foregroundStyle(.secondary)}
                        ForEach(releases){release in
                            VStack(alignment:.leading,spacing:16) {
                                HStack(alignment:.firstTextBaseline) {
                                    Text("Version \(release.version)",bundle:.module).font(.headline)
                                    Spacer()
                                    if let date=releaseDate(release.releaseDate){Text(date,format:.dateTime.month(.abbreviated).day().year()).font(.caption).foregroundStyle(.secondary)}
                                }
                                Text(release.notes.isEmpty ? String(localized:"Release notes are on their way.",bundle:.module):release.notes).font(.body).lineSpacing(4).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)
                                if runtime.config?.features.votes == true {
                                    VoteControl(runtime:runtime,type:"release",id:release.id,up:release.upCount,down:release.downCount,selected:release.myVote)
                                        .id("\(release.id)-\(release.upCount)-\(release.downCount)-\(release.myVote)")
                                }
                            }
                            .padding(20).frame(maxWidth:.infinity,alignment:.leading)
                            .background(Color(uiColor:.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:20))
                        }
                        if nextCursor != nil {
                            Button {Task{await loadMore()}} label:{if loadingMore {ProgressView()}else{Text("Load more updates",bundle:.module)}}.disabled(loadingMore).frame(maxWidth:.infinity,minHeight:44)
                        }
                        if runtime.config?.branding.showPoweredBy == true {Link(String(localized:"Powered by ReleaseKit",bundle:.module),destination:URL(string:"https://releasek.it")!).font(.caption).foregroundStyle(.secondary).frame(maxWidth:.infinity).padding(.top,6)}
                    }.padding(20)
                }
                .background(Color(uiColor:.systemGroupedBackground))
                .refreshable{await refresh()}
            }
        }
        .navigationTitle(String(localized:"What's New",bundle:.module))
        .navigationBarTitleDisplayMode(.inline)
        .task{await refresh()}
        .accessibilityIdentifier("releasekit.changelog")
    }
    private func releaseDate(_ raw:String)->Date? {
        let parser=ISO8601DateFormatter()
        if let date=parser.date(from:raw){return date}
        parser.formatOptions.insert(.withFractionalSeconds)
        return parser.date(from:raw)
    }
    private func refresh() async {
        guard let runtime=ReleaseKit.runtime else{isLoading=false;return}
        guard !loadingMore else{return}
        do{let page=try await runtime.changelog();releases=page.items;nextCursor=page.nextCursor;failed=false}catch{failed=true}
        isLoading=false
    }
    private func loadMore() async {
        guard !loadingMore,let cursor=nextCursor,let runtime=ReleaseKit.runtime else{return}
        loadingMore=true;defer{loadingMore=false}
        do{let page=try await runtime.changelog(cursor:cursor);let ids=Set(releases.map(\.id));releases.append(contentsOf:page.items.filter{!ids.contains($0.id)});nextCursor=page.nextCursor;failed=false}catch{failed=true}
    }
}
public extension View {
    /// Presents a native changelog sheet with its own navigation and close button.
    @MainActor func releaseKitChangelog(isPresented:Binding<Bool>)->some View {
        sheet(isPresented:isPresented){NavigationStack{ReleaseKitChangelogView().toolbar{ToolbarItem(placement:.confirmationAction){Button(String(localized:"Done",bundle:.module)){isPresented.wrappedValue=false}}}}}
    }
}

public struct ReleaseKitSettingsLink<Label:View>:View {
    private let label:Label
    public init(@ViewBuilder label:()->Label){self.label=label()}
    public var body:some View {NavigationLink {ReleaseKitChangelogView()} label:{label}}
}
public extension ReleaseKitSettingsLink where Label == SwiftUI.Label<Text,Image> {
    init(){self.init{SwiftUI.Label(String(localized:"What's New",bundle:.module),systemImage:"sparkles")}}
}
#endif
