import SwiftUI
import A0Core

struct ProjectChatLabel: View {
    @Environment(\.a0Theme) private var theme
    let project:ProjectSummary?
    var body: some View {
        if let project { ProjectDot(color:project.color).accessibilityLabel("Project: " + project.displayTitle) }
        else { Image(systemName:"bubble.left").foregroundStyle(theme.muted).accessibilityHidden(true) }
    }
}
struct ProjectChatFilter: View {
    @Environment(\.a0Theme) private var theme
    let chats:[SpikeModel.ChatSummary]
    @Binding var selection:String?
    private var projects:[ProjectSummary] {
        var seen = Set<String>()
        return chats.compactMap(\.project).filter { seen.insert($0.name).inserted }.sorted { $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending }
    }
    var body: some View {
        if !projects.isEmpty || selection != nil {
            Menu {
                Button("All projects") { selection = nil }
                ForEach(projects) { project in
                    Button { selection = project.name } label: { Label(project.displayTitle,systemImage:selection == project.name ? "checkmark" : "folder") }
                }
            } label: {
                HStack {
                    Label(projects.first(where:{$0.name == selection})?.displayTitle ?? "All projects",systemImage:"line.3.horizontal.decrease")
                    Spacer(); Image(systemName:"chevron.down").font(.caption)
                }.frame(minHeight:44)
            }.accessibilityIdentifier("projectChatFilter")
                .onChange(of:projects.map(\.name)) { _,names in if let selection,!names.contains(selection) { self.selection = nil } }
        }
    }
}
