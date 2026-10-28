#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import ReleaseKitCore

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
        VStack(alignment:.leading,spacing:8) {
            HStack(spacing:10) {
                button(value:1,count:state.upCount,symbol:"hand.thumbsup",label:String(localized:"Upvote",bundle:.module))
                button(value:-1,count:state.downCount,symbol:"hand.thumbsdown",label:String(localized:"Downvote",bundle:.module))
                if busy {ProgressView().controlSize(.small).accessibilityLabel(Text("Saving vote",bundle:.module))}
            }
            if failed {Text(String(localized:"Could not save your vote.",bundle:.module)).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("releasekit.vote.error")}
        }
    }
    private func button(value:Int,count:Int,symbol:String,label:String)->some View {
        Button {Task{await submit(value)}} label:{
            Label("\(count)",systemImage:state.selected==value ? symbol+".fill":symbol)
                .font(compact ? .caption.weight(.medium):.subheadline.weight(.medium)).monospacedDigit()
                .frame(minWidth:compact ? 30:54,minHeight:44)
                .padding(.horizontal,compact ? 6:8)
                .background(state.selected==value ? Color.accentColor.opacity(0.14):Color.secondary.opacity(0.08),in:RoundedRectangle(cornerRadius:12))
                .foregroundStyle(state.selected==value ? Color.accentColor:Color.secondary)
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
                .foregroundStyle(badge == .installed ? Color.green:Color.accentColor)
                .background((badge == .installed ? Color.green:Color.accentColor).opacity(0.12),in:Capsule())
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
    @State private var reportComment:Comment?
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
                    if loading {ProgressView(String(localized:"Loading comments…",bundle:.module))}
                    if failed {Text("Could not load comments.",bundle:.module).foregroundStyle(.secondary);Button(String(localized:"Try again",bundle:.module)){Task{await refresh()}}}
                    if comments.isEmpty && !failed && !loading {Text("No comments yet.",bundle:.module).foregroundStyle(.secondary)}
                    ForEach(comments){comment in
                        commentRow(comment)
                        ForEach(comment.replies){reply in commentRow(reply).padding(.leading,16)}
                    }
                    if nextCursor != nil {Button(String(localized:"Load more comments",bundle:.module)){Task{await loadMore()}}.disabled(loadingMore)}
                    if actionFailed {Text("This action could not be completed.",bundle:.module).font(.caption).foregroundStyle(.secondary)}
                    Button {replyTo=nil;startCompose()} label:{Label(String(localized:"Add comment",bundle:.module),systemImage:"square.and.pencil")}
                        .disabled(runtime.config?.me.banned == true).accessibilityIdentifier("releasekit.comment.add")
                } else {Text("Comments are disabled for this app.",bundle:.module).foregroundStyle(.secondary)}
            }
            Section {
                if let email=runtime.config?.developer.contactEmail,let url=URL(string:"mailto:\(email)"){Link(String(localized:"Contact developer",bundle:.module),destination:url)}
                if let url=runtime.config?.legal.guidelinesUrl {Link(String(localized:"Community guidelines",bundle:.module),destination:url)}
                if runtime.config?.branding.showPoweredBy == true {Link(String(localized:"Powered by ReleaseKit",bundle:.module),destination:URL(string:"https://releasek.it")!).font(.caption).foregroundStyle(.secondary)}
            }
        }
        .navigationTitle(release.version).navigationBarTitleDisplayMode(.inline)
        .task{await refresh()}.refreshable{await refresh()}
        .sheet(isPresented:$showGuidelines,onDismiss:{if agreed {agreed=false;showCompose=true}}){guidelines}
        .sheet(isPresented:$showCompose){ComposeComment(runtime:runtime,version:release.version,parentId:replyTo,onSaved:{Task{await refresh()}})}
        .confirmationDialog(String(localized:"Report comment",bundle:.module),isPresented:Binding(get:{reportComment != nil},set:{if !$0{reportComment=nil}}),titleVisibility:.visible){
            ForEach(["spam","abuse","hate","sexual","illegal","other"],id:\.self){reason in Button(reason.capitalized){if let id=reportComment?.id {Task{do{try await runtime.report(id:id,reason:reason)}catch{actionFailed=true};reportComment=nil}}}}
            Button(String(localized:"Cancel",bundle:.module),role:.cancel){reportComment=nil}
        }
    }
    private var guidelines:some View {
        NavigationStack {
            VStack(alignment:.leading,spacing:20) {
                Text("Be respectful. Do not post abuse, hate, spam, or private information.",bundle:.module)
                if let url=runtime.config?.legal.guidelinesUrl {Link(String(localized:"Read the full guidelines",bundle:.module),destination:url)}
                if actionFailed {Text("This action could not be completed.",bundle:.module).foregroundStyle(.secondary)}
                Button(String(localized:"I agree",bundle:.module)){Task{do{try await runtime.acceptGuidelines();agreed=true;showGuidelines=false}catch{actionFailed=true}}}.buttonStyle(.borderedProminent)
                Spacer()
            }.padding().navigationTitle(String(localized:"Community guidelines",bundle:.module)).navigationBarTitleDisplayMode(.inline)
                .toolbar{ToolbarItem(placement:.cancellationAction){Button(String(localized:"Cancel",bundle:.module)){showGuidelines=false}}}
        }
    }
    private func commentRow(_ comment:Comment)->some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {
                Text(comment.author.name ?? "User \(comment.author.tag ?? "")").font(.caption.bold())
                if comment.author.isMe {Text("You",bundle:.module).font(.caption2).foregroundStyle(.secondary)}
                if comment.author.kind=="developer" {Text("Developer",bundle:.module).font(.caption2).foregroundStyle(.tint)}
            }
            Text(comment.body).textSelection(.enabled)
            if comment.status=="pending" {Label(String(localized:"Awaiting review",bundle:.module),systemImage:"clock").font(.caption).foregroundStyle(.secondary)}
        }.padding(.vertical,4).accessibilityElement(children:.contain).contextMenu {
            if comment.status=="visible" {Button(String(localized:"Reply",bundle:.module)){replyTo=comment.id;startCompose()}}
            if !comment.author.isMe {
                Button(String(localized:"Report",bundle:.module)){reportComment=comment}
                if comment.author.kind=="anon" {Button(String(localized:"Block user",bundle:.module),role:.destructive){Task{do{try await runtime.block(id:comment.id);await refresh()}catch{actionFailed=true}}}}
            }
        }
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
                    TextEditor(text:$text).frame(minHeight:140).accessibilityLabel(Text("Comment",bundle:.module)).accessibilityIdentifier("releasekit.comment.body")
                    Text("\(text.count)/1000").font(.caption).foregroundStyle(.secondary)
                } footer:{Text("Your comment will appear publicly after developer review.",bundle:.module)}
                if let error {Section {Text(error).foregroundStyle(.red).accessibilityIdentifier("releasekit.comment.error")}}
            }
            .navigationTitle(String(localized:"Add comment",bundle:.module)).navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(sending)
            .toolbar {
                ToolbarItem(placement:.cancellationAction){Button(String(localized:"Cancel",bundle:.module)){dismiss()}.disabled(sending)}
                ToolbarItem(placement:.confirmationAction){Button {Task{await post()}} label:{if sending {ProgressView()}else{Text("Post",bundle:.module)}}.disabled(sending || text.trimmingCharacters(in:.whitespacesAndNewlines).count<2 || text.count>1000).accessibilityIdentifier("releasekit.comment.post")}
            }
        }
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
