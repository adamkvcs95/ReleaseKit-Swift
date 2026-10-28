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

private struct CommentThreadGuides:ViewModifier {
    let depth:Int
    func body(content:Content)->some View {
        content.padding(.leading,CGFloat(depth)*12)
            .overlay(alignment:.leading) {
                if depth>0 {
                    HStack(spacing:10) {
                        ForEach(0..<depth,id:\.self){_ in Rectangle().fill(Color.secondary.opacity(0.3)).frame(width:2)}
                    }.accessibilityHidden(true).allowsHitTesting(false)
                }
            }
            .listRowInsets(EdgeInsets(top:0,leading:16,bottom:0,trailing:16))
            .alignmentGuide(.listRowSeparatorLeading){_ in CGFloat(depth)*12}
            .alignmentGuide(.listRowSeparatorTrailing){dimensions in dimensions.width}
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

private struct CommentComposition:Identifiable {
    let id=UUID()
    let replyingTo:Comment?

}

private struct CommentThreadRow:Identifiable {
    let comment:Comment;let depth:Int;var loadMore=false
    var id:String {comment.id+(loadMore ? ":more":"")}
}

@MainActor struct ReleaseDetailView:View {
    let release:Release;let runtime:Runtime
    @State private var comments:[Comment]=[]
    @State private var discussionRevision=UUID()
    @State private var replyPages:[String:[Comment]]=[:]
    @State private var replyCursors:[String:String]=[:]
    @State private var loadedReplyParents:Set<String>=[]
    @State private var loadingReplyParents:Set<String>=[]
    @State private var nextCursor:String?
    @State private var loading=true
    @State private var loadingMore=false
    @State private var failed=false
    @State private var actionFailed=false
    @State private var showGuidelines=false
    @State private var agreed=false
    @State private var composition:CommentComposition?
    @State private var pendingComposition:CommentComposition?
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
                    ForEach(threadRows){row in
                        if row.loadMore {
                            Button(String(localized:"Load more replies",bundle:.module)){Task{await loadReplies(row.comment)}}
                                .tint(.indigo).disabled(loadingReplyParents.contains(row.comment.id))
                                .padding(.vertical,12)
                                .modifier(CommentThreadGuides(depth:row.depth+1))
                                .accessibilityIdentifier("releasekit.comment.more.\(row.comment.id)")
                        } else {commentRow(row.comment,depth:row.depth)}
                    }
                    if nextCursor != nil {Button(String(localized:"Load more comments",bundle:.module)){Task{await loadMore()}}.tint(.indigo).disabled(loadingMore)}
                    if actionFailed {Text("This action could not be completed.",bundle:.module).font(.caption).foregroundStyle(.secondary)}
                } else {Text("Comments are disabled for this app.",bundle:.module).foregroundStyle(.secondary)}
            }
        }
        .listRowSpacing(0)
        .navigationTitle(release.version).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if commentsEnabled {
                ToolbarItemGroup(placement:.bottomBar) {
                    Spacer()
                    Button {startCompose()} label:{Image(systemName:"square.and.pencil")}
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
        .sheet(isPresented:$showGuidelines,onDismiss:{if agreed {agreed=false;composition=pendingComposition};pendingComposition=nil}){guidelines}
        .sheet(item:$composition){request in ComposeComment(runtime:runtime,version:release.version,request:request,onSaved:{Task{await refresh()}})}
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
    private func commentRow(_ comment:Comment,depth:Int=0)->some View {
        let removed=comment.isRemoved || hiddenIDs.contains(comment.id)
        return VStack(alignment:.leading,spacing:8) {
            HStack {
                Text(comment.author.name ?? "User \(comment.author.tag ?? "")").font(.caption.bold())
                if comment.author.isMe {Text("You",bundle:.module).font(.caption2).foregroundStyle(.secondary)}
                if comment.author.kind=="developer" {Text("Developer",bundle:.module).font(.caption2).foregroundStyle(Color.indigo)}
                Spacer()
                if !removed && comment.status=="visible" && !comment.author.isMe {
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
                if comment.status=="visible" {
                    HStack(alignment:.top,spacing:12) {
                        if runtime.config?.features.commentVotes == true {
                            VoteControl(runtime:runtime,type:"comment",id:comment.id,up:comment.upCount,down:comment.downCount,selected:comment.myVote,compact:true)
                        }
                        Spacer(minLength:0)
                        Button {startCompose(replyingTo:comment)} label:{
                            Label(String(localized:"Reply",bundle:.module),systemImage:"arrowshape.turn.up.left")
                                .font(.subheadline).frame(minWidth:44,minHeight:44).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).foregroundStyle(.indigo)
                        .disabled(runtime.config?.me.banned == true)
                        .accessibilityIdentifier("releasekit.comment.reply.\(comment.id)")
                    }
                }
                if comment.status=="pending" {Label(String(localized:"Awaiting review",bundle:.module),systemImage:"clock").font(.caption).foregroundStyle(.secondary)}
            }
        }
        .padding(.vertical,12)
        .modifier(CommentThreadGuides(depth:depth))
        .accessibilityElement(children:.contain).contextMenu {
            if !removed && !comment.author.isMe {commentActions(comment)}
        }
    }
    @ViewBuilder private func commentActions(_ comment:Comment)->some View {
        if comment.status=="visible" && !comment.author.isMe {
            Button {Task{await submitReport(comment)}} label:{Label(String(localized:"Report comment",bundle:.module),systemImage:"flag")}
                .disabled(reportedIDs.contains(comment.id)||reportingIDs.contains(comment.id))
                .accessibilityIdentifier("releasekit.comment.report.\(comment.id)")
            if comment.author.kind=="anon" {Button(role:.destructive){Task{do{try await runtime.block(id:comment.id);await refresh()}catch{actionFailed=true}}} label:{Label(String(localized:"Block user",bundle:.module),systemImage:"person.crop.circle.badge.xmark")}}
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
    private func startCompose(replyingTo comment:Comment?=nil){
        actionFailed=false
        let request=CommentComposition(replyingTo:comment)
        if runtime.config?.me.guidelinesAccepted == true {composition=request}
        else {pendingComposition=request;showGuidelines=true}
    }
    private var threadRows:[CommentThreadRow] {
        var rows:[CommentThreadRow]=[]
        func append(_ nodes:[Comment],depth:Int,ancestors:Set<String>){
            for comment in nodes where !ancestors.contains(comment.id) {
                rows.append(CommentThreadRow(comment:comment,depth:depth))
                let children=replyPages[comment.id] ?? comment.replies
                append(children,depth:depth+1,ancestors:ancestors.union([comment.id]))
                let more=loadedReplyParents.contains(comment.id) ? replyCursors[comment.id] != nil : (comment.hasMoreReplies ?? (comment.replyCount>children.count))
                if more {rows.append(CommentThreadRow(comment:comment,depth:depth,loadMore:true))}
            }
        }
        append(comments,depth:0,ancestors:[]);return rows
    }
    private func loadReplies(_ comment:Comment) async {
        guard !loadingReplyParents.contains(comment.id) else{return}
        loadingReplyParents.insert(comment.id);defer{loadingReplyParents.remove(comment.id)}
        let revision=discussionRevision
        let cursor=loadedReplyParents.contains(comment.id) ? replyCursors[comment.id] : (comment.repliesNextCursor ?? (comment.hasMoreReplies == nil ? comment.replies.last?.id:nil))
        do {
            let page=try await runtime.replies(id:comment.id,cursor:cursor)
            guard revision==discussionRevision else{return}
            let previous=replyPages[comment.id] ?? comment.replies,ids=Set(previous.map(\.id))
            replyPages[comment.id]=previous+page.items.filter{!ids.contains($0.id)}
            loadedReplyParents.insert(comment.id);replyCursors[comment.id]=page.nextCursor;actionFailed=false
        } catch {actionFailed=true}
    }
    private func refresh() async {
        guard commentsEnabled else{loading=false;return}
        guard !loadingMore else{return}
        do{let page=try await runtime.comments(version:release.version);comments=page.items;discussionRevision=UUID();replyPages=[:];replyCursors=[:];loadedReplyParents=[];nextCursor=page.nextCursor;failed=false}catch{failed=true}
        loading=false
    }
    private func loadMore() async {
        guard !loadingMore,let cursor=nextCursor else{return};loadingMore=true;defer{loadingMore=false}
        do{let page=try await runtime.comments(version:release.version,cursor:cursor);let ids=Set(comments.map(\.id));comments.append(contentsOf:page.items.filter{!ids.contains($0.id)});nextCursor=page.nextCursor;failed=false}catch{failed=true}
    }
}

@MainActor private struct ComposeComment:View {
    @Environment(\.dismiss) private var dismiss
    let runtime:Runtime;let version:String;let request:CommentComposition;let onSaved:()->Void
    @State private var text=""
    @State private var sending=false
    @State private var error:String?
    var body:some View {
        NavigationStack {
            Form {
                if let target=request.replyingTo {
                    Section {
                        VStack(alignment:.leading,spacing:6) {
                            Text(target.author.name ?? "User \(target.author.tag ?? "")").font(.subheadline.bold())
                            Text(target.body).font(.callout).foregroundStyle(.secondary).lineLimit(3)
                        }.accessibilityIdentifier("releasekit.comment.replyTarget")
                    } header:{Text("Replying to",bundle:.module).textCase(nil)}
                }
                Section {
                    if let name=runtime.config?.me.displayName {LabeledContent(String(localized:"Posting as",bundle:.module),value:name)}
                    TextEditor(text:$text).textInputAutocapitalization(.never).textCase(nil).font(.body).tint(.indigo).frame(minHeight:140).accessibilityLabel(Text("Comment",bundle:.module)).accessibilityIdentifier("releasekit.comment.body")
                    Text("\(text.count)/1000").font(.caption).foregroundStyle(.secondary)
                } footer:{Text("Your comment will appear publicly after posting.",bundle:.module)}
                if let error {Section {Text(error).foregroundStyle(.red).accessibilityIdentifier("releasekit.comment.error")}}
            }
            .navigationTitle(request.replyingTo == nil ? String(localized:"Add comment",bundle:.module):String(localized:"Reply",bundle:.module)).navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(sending)
            .toolbar {
                ToolbarItem(placement:.cancellationAction){Button(String(localized:"Cancel",bundle:.module)){dismiss()}.disabled(sending)}
                ToolbarItem(placement:.confirmationAction){Button {Task{await post()}} label:{if sending {ProgressView()}else{Text("Post",bundle:.module)}}.disabled(sending || text.trimmingCharacters(in:.whitespacesAndNewlines).count<2 || text.count>1000).accessibilityIdentifier("releasekit.comment.post")}
            }
        }.tint(.primary)
    }
    private func post() async {
        sending=true;error=nil;defer{sending=false}
        do{try await runtime.addComment(version:version,body:text,parentId:request.replyingTo?.id);onSaved();dismiss()}
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
