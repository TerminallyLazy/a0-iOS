import SwiftUI
import A0Core

struct PluginsView: View {
    @Environment(\.a0Theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let model:SpikeModel
    @State private var workspace = PluginWorkspace()
    @State private var tab = 0
    @State private var search = ""
    @State private var filter = "All"
    @State private var resolving = false
    @State private var selectedPlugin:String?
    private var installed:[InstalledPlugin] { workspace.plugins.filter { $0.isCustom == (tab == 0) && (search.isEmpty || ($0.title+" "+$0.id+" "+$0.summary).localizedCaseInsensitiveContains(search)) } }
    private var catalog:[PluginHubEntry] {
        workspace.hub.filter { entry in
            (search.isEmpty || (entry.title+" "+entry.id+" "+entry.summary).localizedCaseInsensitiveContains(search)) &&
            (filter == "All" || (filter == "Installed" && workspace.hubInstalled.contains(entry.id)) || (filter == "Updates" && entry.hasUpdate(for:workspace.installed(entry.id))) || entry.tags.contains(filter))
        }
    }
    private var categories:[String] { Array(Set(workspace.hub.flatMap(\.tags))).sorted() }
    var body: some View {
        NavigationStack {
            List {
                Group {
                ThemeSegments(title:"Plugin collection",labels:["Custom","Built-in","Plugin Hub"],values:[0,1,2],selection:$tab,identifier:"pluginCollection")
                if !model.canSubmit || model.demo { Text("Connect to Agent Zero to manage server plugins.").foregroundStyle(theme.muted) }
                if workspace.busy { ProgressView("Loading plugins…") }
                if let notice = workspace.notice { Section { Text(notice); Button("Refresh") { refresh() } }.accessibilityIdentifier("pluginError") }
                if let pending = workspace.pending {
                    Section("Unconfirmed command") {
                        Text(pending.title).font(.headline)
                        Text("Inspect the server state before repeating this command. Refreshing does not clear it.")
                        Button("I checked the outcome") { resolving = true }.accessibilityIdentifier("resolvePluginCommand")
                    }
                }
                if tab != 2 {
                    if installed.isEmpty && !workspace.busy { ContentUnavailableView(search.isEmpty ? (tab == 0 ? "No custom plugins":"No built-in plugins"):"No matching plugins",systemImage:"puzzlepiece.extension",description:Text("Refresh the list or explore Plugin Hub.")) }
                    ForEach(installed) { plugin in
                        VStack(alignment:.leading,spacing:8) {
                            Button { selectedPlugin = plugin.id } label: {
                                HStack {
                                    PluginRow(model:model,thumbnail:plugin.thumbnail,title:plugin.title,summary:plugin.summary,badge:"")
                                    Image(systemName:"chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                                }.contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityIdentifier("plugin-"+plugin.id)
                            HStack {
                                if plugin.alwaysEnabled { Label("Always active",systemImage:"lock").font(.subheadline) }
                                else { Text("Enable plugin").font(.subheadline) }
                                Spacer()
                                Toggle("Enable " + plugin.title,isOn:Binding(get:{ plugin.state == "enabled" },set:{ enabled in
                                    Task { _ = await workspace.run(.activate(plugin,enabled,PluginScope()),model:model) }
                                }))
                                .labelsHidden().toggleStyle(.switch)
                                .disabled(plugin.alwaysEnabled || !["enabled","disabled"].contains(plugin.state) || !workspace.canMutate || !model.canSubmit)
                                .accessibilityHint(plugin.alwaysEnabled ? "This built-in plugin must remain active":"Changes global activation; scoped overrides are preserved")
                                .accessibilityIdentifier("pluginToggle-"+plugin.id)
                            }
                        }.accessibilityElement(children:.contain).listRowBackground(theme.panel)
                    }
                } else {
                    Picker("Filter",selection:$filter) {
                        Text("All").tag("All"); Text("Installed").tag("Installed"); Text("Updates").tag("Updates")
                        ForEach(categories,id:\.self) { Text($0).tag($0) }
                    }
                    if catalog.isEmpty && !workspace.busy { ContentUnavailableView("No Hub plugins to show",systemImage:"square.grid.2x2",description:Text("Refresh Plugin Hub or change the search and filter.")) }
                    ForEach(catalog) { entry in
                        NavigationLink { PluginHubDetailView(model:model,workspace:workspace,entry:entry) } label: {
                            PluginRow(model:model,thumbnail:entry.thumbnail,title:entry.title,summary:entry.summary,badge:entry.suspension.isEmpty ? (entry.hasUpdate(for:workspace.installed(entry.id)) ? "Update available":workspace.hubInstalled.contains(entry.id) ? "Installed":"") : "Suspended")
                        }.accessibilityIdentifier("hub-"+entry.id).listRowBackground(theme.panel)
                    }
                }
                }.listRowBackground(theme.panel).listRowSeparatorTint(theme.border)
            }
            .scrollContentBackground(.hidden).background { ThemeBackdrop() }
            .safeAreaInset(edge:.bottom,spacing:0) {
                ThemeSearchField(text:$search,prompt:tab == 2 ? "Search Plugin Hub":tab == 0 ? "Search custom plugins":"Search built-in plugins")
                    .padding(.horizontal).padding(.vertical,8).background(theme.panel)
            }
            .scrollDismissesKeyboard(.interactively)
            .modifier(ThemeNavigationChrome())
            .navigationDestination(item:$selectedPlugin) { id in PluginDetailView(model:model,workspace:workspace,pluginID:id) }
            .navigationTitle("Plugins").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Done") { dismiss() } }; ToolbarItem(placement:.primaryAction) { Button("Refresh",systemImage:"arrow.clockwise") { refresh() }.disabled(workspace.busy) } }
            .refreshable { await workspace.load(model,includeHub:tab == 2) }
            .task(id:model.connectionGeneration) { await workspace.load(model) }
            .task(id:tab) {
                guard tab == 2,!workspace.hubLoaded else { return }
                while workspace.busy && !Task.isCancelled { try? await Task.sleep(for:.milliseconds(50)) }
                if !Task.isCancelled { await workspace.load(model,includeHub:true) }
            }
            .confirmationDialog("Clear this unconfirmed command?",isPresented:$resolving,titleVisibility:.visible) {
                Button("Clear after inspection") { Task { await workspace.resolve(model) } }
            } message: { Text("Only clear it after checking the server. This does not undo or retry the operation.") }
            .onChange(of:scenePhase) { _,phase in if phase != .active { search = "" } }
        }.pluginPresentationSize()
    }
    private func refresh() { Task { await workspace.load(model,includeHub:tab == 2) } }
}

private struct PluginRow:View {
    @Environment(\.a0Theme) private var theme
    var model:SpikeModel? = nil
    var thumbnail:PluginThumbnail? = nil
    let title:String
    let summary:String
    let badge:String
    var body:some View {
        HStack(alignment:.top,spacing:12) {
            if let model { PluginThumbnailView(model:model,reference:thumbnail) }
            VStack(alignment:.leading) {
                Text(title).font(.headline)
                if !summary.isEmpty { Text(summary).font(.subheadline).foregroundStyle(theme.muted).lineLimit(3) }
                if !badge.isEmpty { Text(badge).font(.caption).foregroundStyle(theme.muted) }
            }.frame(maxWidth:.infinity,alignment:.leading)
        }.frame(minHeight:64).padding(.vertical,4)
    }
}

struct PluginDetailView:View {
    @Environment(\.a0Theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let model:SpikeModel
    let workspace:PluginWorkspace
    let pluginID:String
    @State private var scope = PluginScope()
    @State private var status:PluginToggleStatus?
    @State private var projects:[PluginScopeOption] = []
    @State private var agents:[PluginScopeOption] = []
    @State private var statusError:String?
    @State private var pendingCommand:PluginCommand?
    @State private var confirmsCommand = false
    @State private var screen:PluginScreenRoute?
    private var plugin:InstalledPlugin? { workspace.installed(pluginID) }
    private var readID:String { model.connectionGeneration.uuidString+"|"+scope.project+"|"+scope.agent+"|"+String(workspace.busy) }
    var body:some View {
        Form {
            Group {
            if let notice = workspace.notice { Section { Text(notice).accessibilityIdentifier("pluginCommandNotice") } }
            if let plugin {
                Section { PluginThumbnailView(model:model,reference:plugin.thumbnail,size:104); Text(plugin.summary); LabeledContent("Version",value:plugin.version.isEmpty ? "Not provided":plugin.version); LabeledContent("Type",value:plugin.isCustom ? "Custom":"Built-in") }
                Section {
                    if plugin.hasMain { Button("Open plugin",systemImage:"arrow.up.forward.app") { open(.main) }.accessibilityIdentifier("openPlugin") }
                    if plugin.hasSettings { Button("Plugin settings",systemImage:"slider.horizontal.3") { open(.settings) }.accessibilityIdentifier("pluginSettings") }
                    if plugin.fields["has_readme"] == .bool(true) { NavigationLink("Readme") { PluginDocumentView(model:model,pluginID:pluginID,license:false) } }
                    if plugin.fields["has_license"] == .bool(true) { NavigationLink("License") { PluginDocumentView(model:model,pluginID:pluginID,license:true) } }
                    if !plugin.hasMain && !plugin.hasSettings { Text("This plugin does not provide a screen.").foregroundStyle(theme.muted) }
                }.disabled(!model.canSubmit || workspace.busy || workspace.pending != nil)
                Section("Activation") {
                    if plugin.perProject { Picker("Project",selection:$scope.project) { Text("Global").tag(""); ForEach(projects) { Text($0.title).tag($0.id) } } }
                    if plugin.perAgent { Picker("Agent",selection:$scope.agent) { Text("All agents").tag(""); ForEach(agents) { Text($0.title).tag($0.id) } } }
                    if plugin.alwaysEnabled { Label("Always active",systemImage:"lock") }
                    else if let status {
                        LabeledContent("Status",value:status.enabled ? "Active":"Inactive")
                        if status.loadedScope != scope { Text("Inherited from \(status.loadedScope.label)").font(.caption).foregroundStyle(theme.muted) }
                        Button(status.enabled ? "Deactivate":"Activate") { confirm(.activate(plugin,!status.enabled,scope)) }.disabled(!workspace.canMutate || !model.canSubmit).accessibilityIdentifier("togglePlugin")
                        if status.hasOverride(in:scope) { Button("Remove activation override") { confirm(.removeOverride(plugin,status.path)) }.disabled(!workspace.canMutate || !model.canSubmit) }
                    } else { Text(statusError ?? "Loading activation…").foregroundStyle(theme.muted) }
                }
                if plugin.isCustom { Section { Button("Delete plugin",role:.destructive) { confirm(.delete(plugin)) }.disabled(!workspace.canMutate || !model.canSubmit).accessibilityIdentifier("deletePlugin") } }
            } else { ContentUnavailableView("Plugin unavailable",systemImage:"puzzlepiece.extension",description:Text("It may have been removed from the server.")) }
                    }.listRowBackground(theme.panel)
        }.scrollContentBackground(.hidden).background { ThemeBackdrop() }.modifier(ThemeNavigationChrome())
        .navigationTitle(plugin?.title ?? pluginID)
        .navigationBarTitleDisplayMode(.inline)
        .task(id:readID) { await loadStatus() }
        .confirmationDialog(pendingCommand?.title ?? "Plugin action",isPresented:$confirmsCommand,titleVisibility:.visible) {
            if let command = pendingCommand { Button(command.title,role:isDelete(command) ? .destructive:nil) { Task { let success = await workspace.run(command,model:model); if success && isDelete(command) { dismiss() } else { await loadStatus() } } }.accessibilityIdentifier("confirmPluginCommand") }
        } message: { Text(pendingCommand.map { isDelete($0) ? "Remove \(plugin?.title ?? pluginID) and its configurations from the connected server?":"Apply this change to \(scope.label)? Other scoped overrides are preserved." } ?? "") }
        .sheet(item:$screen,onDismiss:{ Task { await workspace.load(model); await loadStatus() } }) { route in PluginWebScreen(model:model,route:route) }
    }
    private func isDelete(_ command:PluginCommand) -> Bool { if case .delete = command { true } else { false } }
    private func confirm(_ command:PluginCommand) { pendingCommand = command; confirmsCommand = true }
    private func open(_ kind:PluginScreenKind) { screen = try? PluginScreenRoute(pluginID:pluginID,title:plugin?.title ?? pluginID,kind:kind,scope:scope,contextID:model.chat?.selectedContext) }
    private func loadStatus() async {
        guard let plugin,!workspace.busy,model.canSubmit,let client = model.controlClient else { return }
        let owner = model.connectionGeneration,selected = scope
        status = nil; statusError = nil
        do {
            let loaded = try await client.pluginStatus(pluginID,scope:selected)
            let projectOptions = plugin.perProject ? try await client.pluginScopeOptions(agents:false):[]
            let agentOptions = plugin.perAgent ? try await client.pluginScopeOptions(agents:true):[]
            guard owner == model.connectionGeneration,selected == scope,!Task.isCancelled else { return }
            status = loaded; projects = projectOptions; agents = agentOptions
        } catch {
            guard owner == model.connectionGeneration,selected == scope,!Task.isCancelled else { return }
            statusError = "Activation could not be loaded. Go back and refresh."
        }
    }
}

struct PluginHubDetailView:View {
    @Environment(\.a0Theme) private var theme
    @Environment(\.openURL) private var openURL
    let model:SpikeModel
    let workspace:PluginWorkspace
    let entry:PluginHubEntry
    @State private var confirming = false
    @State private var sourceConfirmation = false
    @State private var scan:PluginScreenRoute?
    private var installed:InstalledPlugin? { workspace.installed(entry.id) }
    var body:some View {
        Form {
            Group {
            Section { PluginThumbnailView(model:model,reference:entry.thumbnail,size:104); Text(entry.summary); if !entry.author.isEmpty { LabeledContent("Author",value:entry.author) }; if !entry.version.isEmpty { LabeledContent("Version",value:entry.version) }; if !entry.tags.isEmpty { Text(entry.tags.joined(separator:" · ")).font(.caption) } }
            if let source = entry.source { Section { Button("View source: \(source.host ?? "repository")") { sourceConfirmation = true } } }
            if !entry.suspension.isEmpty { Section("Installation suspended") { Text(entry.suspension) } }
            if let installed {
                Section {
                    NavigationLink("Manage installed plugin") { PluginDetailView(model:model,workspace:workspace,pluginID:installed.id) }
                    if entry.hasUpdate(for:installed) { Button("Update plugin") { confirming = true }.disabled(!workspace.canMutate || !entry.suspension.isEmpty || !model.canSubmit).accessibilityIdentifier("updatePlugin") }
                }
            } else if workspace.hubInstalled.contains(entry.id) { Text("Installed. Refresh to load its details.") }
            else { Section { Button("Install plugin") { confirming = true }.disabled(!workspace.canMutate || entry.source == nil || !entry.suspension.isEmpty || !model.canSubmit).accessibilityIdentifier("installPlugin") } }
            if workspace.plugins.contains(where: { $0.id == "_plugin_scan" && $0.hasMain }) {
                Section { Button("Open Plugin Scanner") { scan = try? PluginScreenRoute(pluginID:"_plugin_scan",title:"Plugin Scanner",kind:.main,contextID:model.chat?.selectedContext) }; Text("Review the repository in the scanner before installation. A scan does not guarantee safety.").font(.caption).foregroundStyle(theme.muted) }
            }
            if workspace.busy { ProgressView("Working…") }
            if let notice = workspace.notice { Text(notice) }
                    }.listRowBackground(theme.panel)
        }.scrollContentBackground(.hidden).background { ThemeBackdrop() }.modifier(ThemeNavigationChrome()).navigationTitle(entry.title)
        .confirmationDialog(installed == nil ? "Install this plugin?":"Update this plugin?",isPresented:$confirming,titleVisibility:.visible) {
            Button(installed == nil ? "Install":"Update") { Task { _ = await workspace.run(installed.map { .update($0) } ?? .install(entry),model:model) } }
        } message: { Text("Third-party plugins execute code on your Agent Zero server and may access its data. Review the source before continuing.") }
        .confirmationDialog("Open repository?",isPresented:$sourceConfirmation,titleVisibility:.visible) {
            if let source = entry.source { Button("Open in browser") { openURL(source) } }
        } message: { Text(entry.source?.absoluteString ?? "") }
        .sheet(item:$scan) { route in PluginWebScreen(model:model,route:route) }
    }
}

private struct PluginDocumentView:View {
    @Environment(\.a0Theme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    let model:SpikeModel
    let pluginID:String
    let license:Bool
    @State private var source:String?
    @State private var failed = false
    var body:some View {
        ScrollView {
            if let source { MarkdownView(source:source).padding() }
            else if failed { ContentUnavailableView("Document unavailable",systemImage:"doc",description:Text("Return to the plugin and try again when connected.")) }
            else { ProgressView("Loading document…") }
        }.navigationTitle(license ? "License":"Readme")
        .task(id:model.connectionGeneration) {
            source = nil; failed = false
            let generation = model.connectionGeneration
            do {
                guard let client = model.controlClient else { throw ClientError.disconnected }
                let result = try await client.pluginDocument(pluginID,license:license)
                guard generation == model.connectionGeneration,!Task.isCancelled else { return }
                source = result
            } catch { if generation == model.connectionGeneration { failed = true } }
        }.onChange(of:scenePhase) { _,phase in if phase != .active { source = nil; failed = true } }
    }
}

#Preview("Plugin rows — loaded") {
    NavigationStack { List {
        PluginRow(title:"Document Tools",summary:"Search and work with documents on the connected server.",badge:"Enabled")
        PluginRow(title:"Plugin Hub",summary:"Discover community plugins.",badge:"Always active")
    }.navigationTitle("Plugins") }
}
#Preview("Plugin rows — accessibility") {
    List { PluginRow(title:"Document Tools",summary:"A longer description that reflows at accessibility sizes.",badge:"Update available") }.environment(\.dynamicTypeSize,.accessibility3)
}

/// Give plugin workflows room on iPad, including accessibility text sizes.
extension View {
    @ViewBuilder func pluginPresentationSize() -> some View {
        if #available(iOS 18.0, *) { self.presentationSizing(.page) }
        else { self.presentationDetents([.large]) }
    }
}
