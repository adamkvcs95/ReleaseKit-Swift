#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import ReleaseKitCore

@MainActor struct VoteControl:View {
    let runtime:Runtime;let type:String;let id:String
    @State private var up:Int;@State private var down:Int;@State private var selected:Int;@State private var busy=false;@State private var failed=false
    init(runtime:Runtime,type:String,id:String,up:Int,down:Int,selected:Int){self.runtime=runtime;self.type=type;self.id=id;_up=State(initialValue:up);_down=State(initialValue:down);_selected=State(initialValue:selected)}
    var body:some View {VStack(alignment:.leading){HStack{button(value:1,count:up,symbol:"hand.thumbsup");button(value:-1,count:down,symbol:"hand.thumbsdown")};if failed {Text(String(localized:"Could not save your vote.",bundle:.module)).font(.caption).foregroundStyle(.secondary)}}}
    private func button(value:Int,count:Int,symbol:String)->some View {Button {Task{await submit(value)}} label:{Label("\(count)",systemImage:selected==value ? symbol+".fill":symbol).frame(minWidth:44,minHeight:44)}.disabled(busy).accessibilityLabel("\(value==1 ? "Upvote" : "Downvote"), \(count) votes\(selected==value ? ", selected" : "")")}
    private func submit(_ value:Int) async {guard !busy else{return};busy=true;defer{busy=false};let next=selected==value ? 0:value;let old=(up,down,selected);if selected==1{up-=1};if selected == -1{down-=1};if next==1{up+=1};if next == -1{down+=1};selected=next;do{let result=try await runtime.vote(type:type,id:id,value:next);up=result.upCount;down=result.downCount;selected=result.myVote;failed=false}catch{(up,down,selected)=old;failed=true}}
}

@MainActor struct ReleaseDetailView:View {
    let release:Release;let runtime:Runtime
    @State private var comments:[Comment]=[];@State private var failed=false;@State private var showGuidelines=false;@State private var showCompose=false;@State private var replyTo:String?;@State private var reportComment:Comment?
    var body:some View {List {
        Section {Text(release.notes).textSelection(.enabled);if runtime.config?.features.votes == true {VoteControl(runtime:runtime,type:"release",id:release.id,up:release.upCount,down:release.downCount,selected:release.myVote)}}
        if runtime.config?.features.comments == true && runtime.options.comments.isEnabled {Section(String(localized:"Comments",bundle:.module)) {if failed {Text(String(localized:"Could not load comments.",bundle:.module)).foregroundStyle(.secondary)};if comments.isEmpty && !failed {Text(String(localized:"No comments yet.",bundle:.module)).foregroundStyle(.secondary)};ForEach(comments){comment in commentRow(comment);ForEach(comment.replies){reply in commentRow(reply).padding(.leading)}};Button(String(localized:"Add comment",bundle:.module)) {replyTo=nil;startCompose()}}}
        Section {if let email=runtime.config?.developer.contactEmail,let url=URL(string:"mailto:\(email)"){Link(String(localized:"Contact developer",bundle:.module),destination:url)};if let url=runtime.config?.legal.guidelinesUrl {Link(String(localized:"Community guidelines",bundle:.module),destination:url)};if runtime.config?.branding.showPoweredBy == true,let url=URL(string:"https://releasek.it"){Link(String(localized:"Powered by ReleaseKit",bundle:.module),destination:url).font(.caption).foregroundStyle(.secondary)}}
    }.navigationTitle(release.version).task{await refresh()}.refreshable{await refresh()}
    .sheet(isPresented:$showGuidelines){NavigationStack {VStack(alignment:.leading,spacing:20){Text(String(localized:"Community guidelines",bundle:.module)).font(.title2.bold());Text(String(localized:"Be respectful. Do not post abuse, hate, spam, or private information.",bundle:.module));if let url=runtime.config?.legal.guidelinesUrl {Link(String(localized:"Read the full guidelines",bundle:.module),destination:url)};Button(String(localized:"I agree",bundle:.module)) {Task{do{try await runtime.acceptGuidelines();showGuidelines=false;showCompose=true}catch{failed=true}}}.buttonStyle(.borderedProminent)}.padding()}}
    .sheet(isPresented:$showCompose){ComposeComment(runtime:runtime,version:release.version,parentId:replyTo,onSaved:{Task{await refresh()}})}
    .confirmationDialog(String(localized:"Report comment",bundle:.module),isPresented:Binding(get:{reportComment != nil},set:{if !$0{reportComment=nil}}),titleVisibility:.visible){ForEach(["spam","abuse","hate","sexual","illegal","other"],id:\.self){reason in Button(reason.capitalized){if let id=reportComment?.id {Task{do{try await runtime.report(id:id,reason:reason)}catch{failed=true};reportComment=nil}}}};Button(String(localized:"Cancel",bundle:.module),role:.cancel){reportComment=nil}}
    }
    private func commentRow(_ comment:Comment)->some View {VStack(alignment:.leading,spacing:6){HStack{Text(comment.author.kind=="developer" ? (comment.author.name ?? "Developer") : "User \(comment.author.tag ?? "")").font(.caption.bold());if comment.author.kind=="developer" {Text(String(localized:"Developer",bundle:.module)).font(.caption2).foregroundStyle(.tint)};if comment.status=="pending" {Text(String(localized:"Awaiting review",bundle:.module)).font(.caption2).foregroundStyle(.secondary)}};Text(comment.body);if runtime.config?.features.votes == true {VoteControl(runtime:runtime,type:"comment",id:comment.id,up:comment.upCount,down:comment.downCount,selected:comment.myVote)}}.accessibilityElement(children:.contain).contextMenu {Button(String(localized:"Reply",bundle:.module)){replyTo=comment.id;startCompose()};if !comment.author.isMe {Button(String(localized:"Report",bundle:.module)){reportComment=comment};if comment.author.kind=="anon" {Button(String(localized:"Block user",bundle:.module),role:.destructive){Task{do{try await runtime.block(id:comment.id);await refresh()}catch{failed=true}}}}}}}
    private func startCompose(){if runtime.config?.me.guidelinesAccepted == true {showCompose=true}else{showGuidelines=true}}
    private func refresh() async {do{comments=try await runtime.comments(version:release.version);failed=false}catch{failed=true}}
}

@MainActor private struct ComposeComment:View {
    @Environment(\.dismiss) private var dismiss
    let runtime:Runtime;let version:String;let parentId:String?;let onSaved:()->Void
    @State private var text="";@State private var sending=false;@State private var failed=false
    var body:some View {NavigationStack {Form {TextEditor(text:$text).frame(minHeight:140);HStack {Text("\(text.count)/1000");Spacer();if failed {Text(String(localized:"Could not post comment.",bundle:.module)).foregroundStyle(.secondary)}}.font(.caption)}.navigationTitle(String(localized:"Add comment",bundle:.module)).toolbar{ToolbarItem(placement:.cancellationAction){Button(String(localized:"Cancel",bundle:.module)){dismiss()}};ToolbarItem(placement:.confirmationAction){Button(String(localized:"Post",bundle:.module)){Task{sending=true;defer{sending=false};do{try await runtime.addComment(version:version,body:text,parentId:parentId);onSaved();dismiss()}catch{failed=true}}}.disabled(sending || text.trimmingCharacters(in:.whitespacesAndNewlines).count<2 || text.count>1000)}}}}
}
#endif
