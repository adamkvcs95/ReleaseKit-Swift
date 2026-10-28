#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import ReleaseKitCore

struct EngagementPill:ViewModifier {
    var compact=true
    func body(content:Content)->some View {
        content
            .background{Capsule().fill(Color(uiColor:.secondarySystemGroupedBackground)).frame(height:compact ? 36:40)}
            .overlay{Capsule().strokeBorder(Color.primary.opacity(0.14),lineWidth:1).frame(height:compact ? 36:40).allowsHitTesting(false)}
    }
}

@MainActor struct VoteControl:View {
    let runtime:Runtime;let type:String;let id:String
    private let initialState:VoteState
    private let compact:Bool
    private var key:String {"\(type):\(id)"}
    private var state:VoteState {runtime.voteStates[key] ?? initialState}
    @State private var busy=false
    @State private var failed=false
    init(runtime:Runtime,type:String,id:String,up:Int,down:Int,selected:Int,compact:Bool=false){self.runtime=runtime;self.type=type;self.id=id;self.compact=compact;initialState=VoteState(up:up,down:down,selected:selected)}
    var body:some View {
        VStack(alignment:.leading,spacing:4) {
            HStack(spacing:0) {
                button(value:1,count:state.upCount,label:String(localized:"Upvote",bundle:.module))
                Rectangle().fill(Color.primary.opacity(0.12)).frame(width:1,height:20).accessibilityHidden(true)
                button(value:-1,count:state.downCount,label:String(localized:"Downvote",bundle:.module))
            }
            .modifier(EngagementPill(compact:compact)).tint(.indigo)
            .fixedSize(horizontal:true,vertical:false)
            if failed {Text(String(localized:"Could not save your vote.",bundle:.module)).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("releasekit.vote.error")}
        }
    }
    private func button(value:Int,count:Int,label:String)->some View {
        Button {Task{await submit(value)}} label:{
            HStack(spacing:8) {
                if busy && value == -1 {ProgressView().controlSize(.small).frame(width:compact ? 19:21,height:24)}
                else {Image(systemName:(value==1 ? "arrowtriangle.up":"arrowtriangle.down")+(state.selected==value ? ".fill":"")).font(.system(size:compact ? 17:19,weight:.medium)).frame(width:compact ? 19:21,height:compact ? 22:24)}
                if value==1 {
                    Text("\(state.upCount-state.downCount)").font(compact ? .subheadline.weight(.semibold):.body.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(state.selected==0 ? Color.primary:Color.indigo)
                }
            }
            .padding(.horizontal,12).frame(minWidth:44,minHeight:44)
            .foregroundStyle(state.selected==value ? Color.indigo:Color.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(busy)
        .accessibilityLabel(label).accessibilityValue(String(count))
        .accessibilityAddTraits(state.selected==value ? [.isSelected]:[])
        .accessibilityHint(Text("Tap again to remove your vote",bundle:.module))
        .accessibilityIdentifier("releasekit.vote.\(value==1 ? "up":"down").\(id)")
    }
    private func submit(_ value:Int) async {
        guard !busy else{return};busy=true;failed=false;defer{busy=false}
        let previous=state;var optimistic=state;let next=optimistic.toggle(value);runtime.voteStates[key]=optimistic
        do {let result=try await runtime.vote(type:type,id:id,value:next);runtime.voteStates[key]=VoteState(up:result.upCount,down:result.downCount,selected:result.myVote)}
        catch {runtime.voteStates[key]=previous;failed=true}
    }
}

@MainActor struct ReleaseVersionBadge:View {
    let version:String;let runtime:Runtime
    var body:some View {
        if let badge=ReleaseBadge.resolve(version:version,installed:runtime.installedVersion,latest:runtime.config?.app.latestVersion) {
            Text(badge == .installed ? String(localized:"Installed",bundle:.module):String(localized:"Latest",bundle:.module))
                .font(.caption2.weight(.semibold)).padding(.horizontal,8).padding(.vertical,4)
                .foregroundStyle(badge == .installed ? Color.green:Color.indigo)
                .background((badge == .installed ? Color.green:Color.indigo).opacity(0.12),in:Capsule())
        }
    }
}

@MainActor struct ReleaseDetailView:View {
    let release:Release;let runtime:Runtime
    @State private var comments:[Comment]=[]
    @State private var nextCursor:String?
    @State private var loading=true
    @State private var loadingMore=false
    @State private var failed=false
    @State private var actionFailed=false
    @State private var showGuidelines=false
    @State private var agreed=false
    @State private var showCompose=false
    @State private var replyTo:String?
    @State private var reportedIDs:Set<String>=[]
    @State private var hiddenIDs:Set<String>=[]
    @State private var reportingIDs:Set<String>=[]
    @State private var reportSubmitted=false
    private var commentsEnabled:Bool {runtime.config?.features.comments == true && runtime.options.comments.isEnabled}
    var body:some View {
        List {
            Section {
                HStack {Text("Version \(release.version)",bundle:.module).font(.headline);Spacer();ReleaseVersionBadge(version:release.version,runtime:runtime)}
                Text(release.notes).textSelection(.enabled).lineSpacing(4)
                if runtime.config?.features.votes == true {VoteControl(runtime:runtime,type:"release",id:release.id,up:release.upCount,down:release.downCount,selected:release.myVote)}
            }
            Section(String(localized:"Comments",bundle:.module)) {
                if commentsEnabled {
                    if runtime.offline {Label(String(localized:"Offline — showing saved comments",bundle:.module),systemImage:"wifi.slash").font(.caption).foregroundStyle(.secondary)}
                    if loading {ProgressView(String(localized:"Loading comments…",bundle:.module)).tint(.indigo)}
                    if failed {Text("Could not load comments.",bundle:.module).foregroundStyle(.secondary);Button(String(localized:"Try again",bundle:.module)){Task{await refresh()}}.tint(.indigo)}
                    if comments.isEmpty && !failed && !loading {Text("No comments yet.",bundle:.module).foregroundStyle(.secondary)}
                    ForEach(comments){comment in
                        commentRow(comment)
                        ForEach(comment.replies){reply in commentRow(reply).padding(.leading,16)}
                    }
                    if nextCursor != nil {Button(String(localized:"Load more comments",bundle:.module)){Task{await loadMore()}}.tint(.indigo).disabled(loadingMore)}
                    if actionFailed {Text("This action could not be completed.",bundle:.module).font(.caption).foregroundStyle(.secondary)}
                } else {Text("Comments are disabled for this app.",bundle:.module).foregroundStyle(.secondary)}
            }
        }
        .navigationTitle(release.version).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if commentsEnabled {
                ToolbarItemGroup(placement:.bottomBar) {
                    Spacer()
                    Button {replyTo=nil;startCompose()} label:{Image(systemName:"square.and.pencil")}
                        .accessibilityLabel(Text("Add comment",bundle:.module))
                        .disabled(runtime.config?.me.banned == true)
                        .accessibilityIdentifier("releasekit.comment.add")
                }
            }
            ToolbarItem(placement:.topBarTrailing) {
                Menu {
                    if let url=runtime.config?.legal.guidelinesUrl {
                        Link(destination:url){Label(String(localized:"Community guidelines",bundle:.module),systemImage:"text.book.closed")}
                    }
                    if let email=runtime.config?.developer.contactEmail,let url=URL(string:"mailto:\(email)") {
                        Link(destination:url){Label(String(localized:"Contact developer",bundle:.module),systemImage:"envelope")}
                    }
                } label:{Image(systemName:"ellipsis").accessibilityLabel(Text("More options",bundle:.module))}
                    .accessibilityIdentifier("releasekit.release.menu")
            }
        }
        .tint(.primary)
        .task{await refresh()}.refreshable{await refresh()}
        .sheet(isPresented:$showGuidelines,onDismiss:{if agreed {agreed=false;showCompose=true}}){guidelines}
        .sheet(isPresented:$showCompose){ComposeComment(runtime:runtime,version:release.version,parentId:replyTo,onSaved:{Task{await refresh()}})}
        .alert(String(localized:"Report submitted",bundle:.module),isPresented:$reportSubmitted){Button("OK",role:.cancel){}} message:{Text("Thank you. Your report has been submitted.",bundle:.module)}
    }
    private var guidelines:some View {
        NavigationStack {
            VStack(alignment:.leading,spacing:20) {
                Text("Be respectful. Do not post abuse, hate, spam, or private information.",bundle:.module)
                if let url=runtime.config?.legal.guidelinesUrl {Link(String(localized:"Read the full guidelines",bundle:.module),destination:url).tint(.indigo)}
                if actionFailed {Text("This action could not be completed.",bundle:.module).foregroundStyle(.secondary)}
                Button(String(localized:"I agree",bundle:.module)){Task{do{try await runtime.acceptGuidelines();agreed=true;showGuidelines=false}catch{actionFailed=true}}}.buttonStyle(.borderedProminent).tint(.indigo)
                Spacer()
            }.padding().navigationTitle(String(localized:"Community guidelines",bundle:.module)).navigationBarTitleDisplayMode(.inline)
                .toolbar{ToolbarItem(placement:.cancellationAction){Button(String(localized:"Cancel",bundle:.module)){showGuidelines=false}}}
        }.tint(.primary)
    }
    private func commentRow(_ comment:Comment)->some View {
        let removed=comment.isRemoved || hiddenIDs.contains(comment.id)
        return VStack(alignment:.leading,spacing:8) {
            HStack {
                Text(comment.author.name ?? "User \(comment.author.tag ?? "")").font(.caption.bold())
                if comment.author.isMe {Text("You",bundle:.module).font(.caption2).foregroundStyle(.secondary)}
                if comment.author.kind=="developer" {Text("Developer",bundle:.module).font(.caption2).foregroundStyle(Color.indigo)}
                Spacer()
                if !removed && comment.status=="visible" {
                    Menu {commentActions(comment)} label:{Image(systemName:"ellipsis").frame(minWidth:44,minHeight:44).contentShape(Rectangle())}
                        .accessibilityLabel(Text("Comment actions",bundle:.module)).accessibilityIdentifier("releasekit.comment.menu.\(comment.id)")
                }
            }
            if removed {
                Label {Text(verbatim:hiddenCommentNotice)} icon:{Image(systemName:"eye.slash")}
                    .font(.callout).foregroundStyle(.secondary).accessibilityIdentifier("releasekit.comment.hidden.\(comment.id)")
            } else {
                Text(comment.body).textSelection(.enabled)
                if comment.author.verified == true {Label(String(localized:"Verified app",bundle:.module),systemImage:"checkmark.shield").font(.caption2).foregroundStyle(.secondary)}
                if comment.status=="visible",runtime.config?.features.commentVotes == true {
                    VoteControl(runtime:runtime,type:"comment",id:comment.id,up:comment.upCount,down:comment.downCount,selected:comment.myVote,compact:true)
                }
                if comment.status=="pending" {Label(String(localized:"Awaiting review",bundle:.module),systemImage:"clock").font(.caption).foregroundStyle(.secondary)}
            }
        }.padding(.vertical,4).accessibilityElement(children:.contain).contextMenu {
            if !removed {commentActions(comment)}
        }
    }
    @ViewBuilder private func commentActions(_ comment:Comment)->some View {
        if comment.status=="visible" {Button(String(localized:"Reply",bundle:.module)){replyTo=comment.id;startCompose()}}
        if comment.status=="visible" && !comment.author.isMe {
            Button {Task{await submitReport(comment)}} label:{Label(String(localized:"Report comment",bundle:.module),systemImage:"flag")}
                .disabled(reportedIDs.contains(comment.id)||reportingIDs.contains(comment.id))
                .accessibilityIdentifier("releasekit.comment.report.\(comment.id)")
            if comment.author.kind=="anon" {Button(String(localized:"Block user",bundle:.module),role:.destructive){Task{do{try await runtime.block(id:comment.id);await refresh()}catch{actionFailed=true}}}}
        }
    }
    private func submitReport(_ comment:Comment) async {
        guard !reportingIDs.contains(comment.id),!reportedIDs.contains(comment.id) else{return}
        reportingIDs.insert(comment.id);actionFailed=false;defer{reportingIDs.remove(comment.id)}
        do {
            let result=try await runtime.report(id:comment.id,version:release.version)
            if result.hidden==true {hiddenIDs.insert(comment.id)}
            reportedIDs.insert(comment.id);await refresh();reportSubmitted=true
        } catch {actionFailed=true}
    }
    private func startCompose(){actionFailed=false;if runtime.config?.me.guidelinesAccepted == true {showCompose=true}else{showGuidelines=true}}
    private func refresh() async {
        guard commentsEnabled else{loading=false;return}
        guard !loadingMore else{return}
        do{let page=try await runtime.comments(version:release.version);comments=page.items;nextCursor=page.nextCursor;failed=false}catch{failed=true}
        loading=false
    }
    private func loadMore() async {
        guard !loadingMore,let cursor=nextCursor else{return};loadingMore=true;defer{loadingMore=false}
        do{let page=try await runtime.comments(version:release.version,cursor:cursor);let ids=Set(comments.map(\.id));comments.append(contentsOf:page.items.filter{!ids.contains($0.id)});nextCursor=page.nextCursor;failed=false}catch{failed=true}
    }
}

@MainActor private struct ComposeComment:View {
    @Environment(\.dismiss) private var dismiss
    let runtime:Runtime;let version:String;let parentId:String?;let onSaved:()->Void
    @State private var text=""
    @State private var sending=false
    @State private var error:String?
    var body:some View {
        NavigationStack {
            Form {
                Section {
                    if let name=runtime.config?.me.displayName {LabeledContent(String(localized:"Posting as",bundle:.module),value:name)}
                    TextEditor(text:$text).tint(.indigo).frame(minHeight:140).accessibilityLabel(Text("Comment",bundle:.module)).accessibilityIdentifier("releasekit.comment.body")
                    Text("\(text.count)/1000").font(.caption).foregroundStyle(.secondary)
                } footer:{Text("Your comment will appear publicly after posting.",bundle:.module)}
                if let error {Section {Text(error).foregroundStyle(.red).accessibilityIdentifier("releasekit.comment.error")}}
            }
            .navigationTitle(String(localized:"Add comment",bundle:.module)).navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(sending)
            .toolbar {
                ToolbarItem(placement:.cancellationAction){Button(String(localized:"Cancel",bundle:.module)){dismiss()}.disabled(sending)}
                ToolbarItem(placement:.confirmationAction){Button {Task{await post()}} label:{if sending {ProgressView()}else{Text("Post",bundle:.module)}}.disabled(sending || text.trimmingCharacters(in:.whitespacesAndNewlines).count<2 || text.count>1000).accessibilityIdentifier("releasekit.comment.post")}
            }
        }.tint(.primary)
    }
    private func post() async {
        sending=true;error=nil;defer{sending=false}
        do{try await runtime.addComment(version:version,body:text,parentId:parentId);onSaved();dismiss()}
        catch ReleaseKitNetworkError.server(let code) {
            switch code {
            case "rate_limited":error=String(localized:"Too many comments. Please try again later.",bundle:.module)
            case "content_rejected":error=String(localized:"This comment could not be accepted. Please edit it and try again.",bundle:.module)
            case "banned":error=String(localized:"Commenting is unavailable for this user.",bundle:.module)
            default:error=String(localized:"Could not post comment.",bundle:.module)
            }
        } catch {self.error=String(localized:"Could not post comment.",bundle:.module)}
    }
}
#endif
