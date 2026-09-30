import SwiftUI
import A0Core
import A0GenerativeUI
import A0Realtime

@MainActor @Observable final class SpikeModel {
    let serverTheme = ServerThemeStore()
    var themeRefreshRevision = 0
    var origin = ""
    var localDevelopment = false
    var username = ""
    var password = ""
    var profileName = ""
    var rememberPassword = false
    var profiles: [SavedProfile] = []
    var profileBusy = false
    var credentialLoaded = false
    var profileNotice: String?
    private var profileLibrary: ProfileLibrary?
    private let fixtureID = UUID()
    var status = "Not connected"
    var detail = "Connect to an authenticated HTTPS Agent Zero server."
    var state = SyncReducer() {
        didSet {
            updateJevReplies()
            if oldValue.contexts != state.contexts || oldValue.needsFullSync != state.needsFullSync {
                updateSubagents()
            }
        }
    }
    private(set) var subagentRelationships = SubagentRelationships(contexts:[])
    private(set) var subagentDiscovery = SubagentDiscovery()
    // Transport generations change on backgrounding; discovery belongs to the
    // authenticated session and survives a read-only foreground refresh.
    private var subagentDiscoveryScope = UUID()
    private func resetSubagentDiscovery() {
        subagentDiscoveryScope = UUID()
        subagentDiscovery = SubagentDiscovery()
    }
    private func updateSubagents() {
        subagentRelationships = SubagentRelationships(contexts:state.contexts)
        subagentDiscovery.reconcile(subagentRelationships,scope:subagentDiscoveryScope,fresh:!state.needsFullSync)
    }
    func newSubagents(in context: String) -> Set<String> { subagentDiscovery.newIDs(parent:context) }
    var jevCoordinator: JevCoordinator?
    private var jevStore: JevSettingsStore?
    private var pendingJev: (context:String, baseline:[LogEntry], key:String)?
    private var preparingJevSend = false
    private var jevRevision = UUID()
    var connecting = false
    var connected = false
    var demo = false
    var recoveryStopped = false
    private var syncInterrupted = false
    struct ChatSummary: Identifiable {
        let id: String
        let name: String
        let project: ProjectSummary?
    }
    var chatSummaries: [ChatSummary] {
        state.contexts.compactMap { context in
            guard let id = context["id"]?.string else { return nil }
            return ChatSummary(id: id, name: context["name"]?.string ?? id, project: ProjectSummary(context:context))
        }
    }
    var canConnect: Bool {
        !connecting && !profileBusy && !origin.isEmpty
            && (localDevelopment || (!username.isEmpty && !password.isEmpty))
    }
    var canSubmit: Bool { !preparingJevSend && !stoppingAgent && (demo || (connected && !syncInterrupted && !state.needsFullSync)) }
    var agentIsRunning: Bool {
        guard let contextID = chat?.selectedContext else { return false }
        let context = state.contexts.first { $0["id"]?.string == contextID }
        return context?["running"] == .bool(true) || (state.context == contextID && state.progressActive)
    }
    var stoppingAgent = false
    var stopNotice: String?
    func stopAgent() async {
        guard !stoppingAgent, canSubmit, !demo, let client,
              let context = chat?.selectedContext,
              let profile = try? ProfileIdentity(origin:ServerOrigin(origin),username:username) else { return }
        let generation = connectionGeneration
        let session = chat
        stoppingAgent = true; stopNotice = nil
        defer { stoppingAgent = false }
        var receipt: ControlJournal.Receipt?
        do {
            let intent = ControlJournal.Receipt(title:AgentControl.stop.title,context:context,profile:profile)
            try await ControlReceipts.journal.begin(intent); receipt = intent
            guard generation == connectionGeneration, context == chat?.selectedContext, connected, !syncInterrupted, !state.needsFullSync else {
                try await ControlReceipts.journal.resolve(intent); return
            }
            let result = try await client.perform(.stop,context:context)
            session?.recordClearedQueue(context:context)
            try await ControlReceipts.journal.resolve(intent)
            guard generation == connectionGeneration, context == chat?.selectedContext else { return }
            stopNotice = result.text
        } catch {
            guard generation == connectionGeneration, context == chat?.selectedContext else { return }
            stopNotice = receipt == nil
                ? "Stop was not sent. Check saved actions in Chat tools and try again."
                : "Stop outcome unconfirmed. Check the agent and queue in the WebUI before repeating."
        }
    }
    var chat: ChatSession?
    private var chatsByProfile: [ProfileIdentity: ChatSession] = [:]
    private var sessionStore: (any SessionStoring)?
    private var client: APIClient?
    var controlClient: APIClient? { client }
    var connectionGeneration: UUID { generation }
    private var backgrounded = false
    private var activeIdentity: ProfileIdentity?
    private var sessionKeychain: KeychainSessionStore?
    private var sessionPersistence: Task<Void, Never>?
    private var lastSavedAuthentication: SavedAuthentication?
    private var restorationPending = false
    var restoredSession = false

    private func authenticationStore() -> KeychainSessionStore {
        if let sessionKeychain { return sessionKeychain }
        var suffix = usesFixture ? ".test." + testNamespace.uuidString : ""
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--loopback-probe") { suffix = ".development" }
        #endif
        let store = KeychainSessionStore(service: "local.agentzero.active-session.v1" + suffix)
        sessionKeychain = store; return store
    }
    private func saveAuthentication(_ client: APIClient, identity: ProfileIdentity, generation: UUID) async {
        guard let saved = try? await client.savedAuthentication(for: identity), generation == self.generation,
              saved != lastSavedAuthentication else { return }
        let store = authenticationStore(), previous = sessionPersistence
        let write = Task { [weak self] in
            await previous?.value
            do { try await store.save(saved) }
            catch {
                guard let self, self.generation == generation else { return }
                self.profileNotice = "This session could not be saved securely. Keep the app open or sign in again after closing it."
                return
            }
            guard let self, self.generation == generation else { return }
            self.lastSavedAuthentication = saved
        }
        sessionPersistence = write
        await write.value
    }
    private func clearSavedAuthentication() {
        lastSavedAuthentication = nil
        let store = authenticationStore(), previous = sessionPersistence
        sessionPersistence = Task { [weak self] in
            await previous?.value
            do { try await store.remove() }
            catch { self?.profileNotice = "The saved session could not be removed. Unlock this device and disconnect again." }
        }
    }
    /// Called once at startup and on unlock when a prior restore was temporarily unavailable.
    func restoreSession() async {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if (usesFixture || args.contains("--loopback-probe")), !args.contains("--synthetic-session-restore") { return }
        #endif
        guard !connected, !connecting, !demo, !backgrounded else { return }
        let generation = self.generation
        connecting = true; status = "Restoring session"
        do {
            await sessionPersistence?.value
            let savedSession = try await authenticationStore().load()
            guard generation == self.generation, !backgrounded else { return }
            guard let saved = savedSession else {
                connecting = false; restorationPending = false; status = "Not connected"; return
            }
            let identity = saved.profile
            let serverOrigin = try ServerOrigin(identity.origin)
            var transport: any HTTPTransport = URLSessionTransport()
            #if DEBUG
            if usesFixture { transport = PreviewHTTPTransport() }
            #endif
            let client = APIClient(origin: serverOrigin, transport: transport)
            self.client = client
            try await client.restore(saved, for: identity)
            guard generation == self.generation, !backgrounded else { return }
            let restored = try await ChatSession.restoring(api: client, profile: identity, store: repository())
            guard generation == self.generation, !backgrounded else { return }
            restored.resume(api: client)
            chat = restored; chatsByProfile[identity] = restored
            resetSubagentDiscovery()
            activeIdentity = identity; origin = identity.origin; username = identity.username
            profileName = profiles.first(where: { $0.identity == identity })?.name ?? identity.origin
            state.select(context: restored.selectedContext)
            let snapshot = try await client.poll(state.request)
            guard generation == self.generation, !backgrounded else { return }
            _ = state.apply(snapshot: snapshot, generation: state.generation, full: true)
            restored.reconcile(snapshot)
            await saveAuthentication(client, identity: identity, generation: generation)
            guard generation == self.generation, !backgrounded else { return }
            connecting = false; restoredSession = true; connected = true; restorationPending = false
            startPolling()
        } catch {
            guard generation == self.generation, !backgrounded else { return }
            connecting = false
            if let error = error as? ClientError,
               [.requiresLogin, .csrfRejected, .unauthenticatedServer, .invalidOrigin].contains(error) {
                disconnect(); status = "Sign in again"; detail = error.localizedDescription
            } else {
                restorationPending = true; status = "Session waiting"
                detail = "Your session is saved. Reopen after unlocking or when the server is reachable; no messages are resent."
            }
        }
    }
    func resume() {
        guard backgrounded else { return }
        backgrounded = false
        if connected, client != nil {
            status = "Catching up"; detail = "Restoring the latest server state. Your Agent Zero work continues on the server."
            startPolling()
        } else if restorationPending {
            Task { await restoreSession() }
        }
    }
    private let realtime: any RealtimeConnecting = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--synthetic-realtime-") }) {
            return PreviewRealtimeClient()
        }
        #endif
        return RealtimeClient()
    }()
    private var socketID: UUID?
    private var candidate: RealtimeHandoff?
    private var promotion: Task<Void, Never>?
    private var pollingID = UUID()
    private var realtimeRetryNotice = false
    private var operation: Task<Void, Never>?
    private var polling: Task<Void, Never>?
    private var generation = UUID()

    func connect() {
        guard !profileBusy else { return }
        let username = username, password = password, origin = origin
        let rememberPassword = rememberPassword, profileName = profileName
        disconnect()
        let generation = self.generation
        connecting = true; status = "Signing in"
        operation = Task {
            do {
                var policy: OriginPolicy = .httpsOnly
                #if DEBUG
                if localDevelopment { policy = .loopbackDevelopment }
                #endif
                let serverOrigin = try ServerOrigin(origin, policy: policy)
                var transport: any HTTPTransport = URLSessionTransport()
                #if DEBUG
                if usesFixture { transport = PreviewHTTPTransport() }
                #endif
                let client = APIClient(origin: serverOrigin, transport: transport)
                self.client = client
                try await client.connect(username: username, password: password)
                guard generation == self.generation, !Task.isCancelled else { return }
                let serverKey = ProfileIdentity(origin: serverOrigin, username: username)
                activeIdentity = serverKey
                await saveAuthentication(client, identity: serverKey, generation: generation)
                guard generation == self.generation, !Task.isCancelled else { return }
                do {
                    let library = try await library()
                    try await library.recordLogin(SavedProfile(identity: serverKey, name: profileName, localDevelopment: localDevelopment),
                                                  password: password, rememberPassword: rememberPassword)
                    let saved = try await library.load()
                    guard generation == self.generation, !Task.isCancelled else { return }
                    profiles = saved; profileNotice = nil
                } catch {
                    guard generation == self.generation, !Task.isCancelled else { return }
                    profileNotice = "Signed in, but server details or password could not be saved. Unlock the device or free up space, then try again."
                }
                let chat: ChatSession
                if let existing = chatsByProfile[serverKey] { chat = existing }
                else { chat = try await ChatSession.restoring(api: client, profile: serverKey, store: repository()) }
                guard generation == self.generation, !Task.isCancelled else { return }
                chat.resume(api: client)
                chatsByProfile[serverKey] = chat; self.chat = chat
                state.select(context: chat.selectedContext)
                let snapshot = try await client.poll(state.request)
                try Task.checkCancellation()
                guard generation == self.generation else { return }
                _ = state.apply(snapshot: snapshot, generation: state.generation, full: true)
                chat.reconcile(snapshot)
                self.password = ""; connecting = false; connected = true
                status = "Opening realtime connection"; detail = localDevelopment ? "Local development snapshot received; this is not remote-auth acceptance." : "Authenticated HTTP snapshot received."
                #if DEBUG
                if usesFixture {
                    startPolling(); detail = "Synthetic HTTP fixture; no server connection."
                    return
                }
                #endif
                let session = try await client.socketSession()
                let id = UUID(); socketID = id
                installRealtimeHandler(id: id, generation: generation)
                realtime.connect(session: session, request: StateRequest(context: state.context))
            } catch {
                guard generation == self.generation, !Task.isCancelled else { return }
                fail(error)
            }
        }
    }
    private var usesFixture: Bool {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        return args.contains(where: { $0.hasPrefix("--synthetic-") }) || args.contains("--profile-ui-test")
        #else
        return false
        #endif
    }
    private var testNamespace: UUID {
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of:"--persistence-test-id"), args.indices.contains(index + 1),
           let id = UUID(uuidString:args[index + 1]) { return id }
        return fixtureID
    }
    private func storageDirectory() throws -> URL {
        var directory = try FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true)
            .appendingPathComponent("AgentZeroSessions",isDirectory:true)
        if usesFixture { directory = directory.appendingPathComponent("UITests").appendingPathComponent(testNamespace.uuidString) }
        return directory
    }
    private func library() async throws -> ProfileLibrary {
        if let profileLibrary { return profileLibrary }
        let directory = try storageDirectory().appendingPathComponent("Profiles",isDirectory:true)
        let store = try await Task.detached { try ProfileRepository(directory:directory) }.value
        let service = "local.agentzero.saved-credentials.v1" + (usesFixture ? ".test." + testNamespace.uuidString : "")
        let library = ProfileLibrary(profiles:store, credentials:KeychainCredentialStore(service:service))
        profileLibrary = library; return library
    }
    func loadProfiles() async {
        profileBusy = true
        defer { profileBusy = false }
        do { profiles = try await library().load() }
        catch { profileNotice = "Saved servers could not be opened. Unlock this device and try again. Existing data is kept." }
    }
    func editOrigin(_ value: String) {
        guard value != origin else { return }
        origin = value; invalidateLoadedPassword()
    }
    func useQRDestination(_ destination: QRDestination) {
        disconnect()
        invalidateLoadedPassword()
        origin = destination.origin.header
        username = ""; profileName = ""; localDevelopment = false
        detail = "Server address added. Enter your credentials to connect."
    }
    func editUsername(_ value: String) {
        guard value != username else { return }
        username = value; invalidateLoadedPassword()
    }
    private func invalidateLoadedPassword() {
        generation = UUID(); password = ""; credentialLoaded = false; rememberPassword = false; profileNotice = nil
    }
    func selectProfile(_ profile: SavedProfile) async {
        disconnect(); profileBusy = true
        let generation = generation
        defer { if generation == self.generation { profileBusy = false } }
        origin = profile.identity.origin; username = profile.identity.username; profileName = profile.name
        localDevelopment = profile.localDevelopment; rememberPassword = false
        do {
            let saved = try await library().password(for:profile.identity)
            guard generation == self.generation else { return }
            password = saved ?? ""; credentialLoaded = saved != nil; rememberPassword = saved != nil
            profileNotice = nil
        } catch {
            guard generation == self.generation else { return }
            profileNotice = "Saved password unavailable. Unlock this device or enter your password to connect."
        }
    }
    func forgetPassword() async {
        profileBusy = true
        defer { profileBusy = false }
        do {
            var policy: OriginPolicy = .httpsOnly
            #if DEBUG
            if localDevelopment { policy = .loopbackDevelopment }
            #endif
            let identity = ProfileIdentity(origin:try ServerOrigin(origin,policy:policy),username:username)
            try await library().forgetPassword(identity)
            password = ""; credentialLoaded = false; rememberPassword = false
            profileNotice = "Saved password removed"
        } catch { profileNotice = "Password could not be removed. Unlock the device and try again." }
    }
    func removeProfile(_ profile: SavedProfile) async {
        profileBusy = true
        defer { profileBusy = false }
        do {
            invalidateJev()
            try await jevSettingsStore().remove(profile.identity)
            try await library().remove(profile.identity)
            if activeIdentity == profile.identity { disconnect() }
            profiles = try await library().load()
            if origin == profile.identity.origin && username == profile.identity.username {
                origin = ""; username = ""; profileName = ""; invalidateLoadedPassword()
            }
            profileNotice = "Saved server removed. Its local drafts are kept."
        } catch { profileNotice = "Server could not be removed. Unlock the device and try again." }
    }
    private func repository() async throws -> any SessionStoring {
        if let sessionStore { return sessionStore }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--synthetic-storage-failure") {
            let store = PreviewFailingStore(); sessionStore = store; return store
        }
        #endif
        let directory = try storageDirectory()
        let store = try await Task.detached { try SessionRepository(directory:directory) }.value
        sessionStore = store; return store
    }
    private func installRealtimeHandler(id: UUID, generation: UUID) {
        realtime.onEvent = { [weak self] event in
            guard let self, self.generation == generation, self.socketID == id else { return }
            self.handle(event)
        }
    }
    private func handle(_ event: RealtimeEvent) {
        if var candidate {
            switch event {
            case .handshake(let epoch, let sequenceBase):
                candidate.handshake(epoch: epoch, sequenceBase: sequenceBase)
                self.candidate = candidate
            case .push(let push):
                guard let current = candidate.accept(push, replacing: state) else {
                    endRealtimeAttempt(); return
                }
                // MainActor handoff is atomic. Canceled poll completions cannot publish.
                pollingID = UUID(); polling?.cancel(); polling = nil
                promotion?.cancel(); promotion = nil; self.candidate = nil
                state = current; realtimeRetryNotice = false
                chat?.reconcile(push.data.snapshot)
                status = "Live"; detail = "Socket.IO state is current."
                synchronizeSelection()
            case .failed: endRealtimeAttempt()
            }
            return
        }
        switch event {
        case .handshake(let epoch, let sequenceBase):
            state.beginHandshake(epoch: epoch, sequenceBase: sequenceBase)
            status = "Synchronizing"; detail = "State handler accepted. Waiting for full state."
        case .push(let push):
            let result = state.apply(push: push, generation: state.generation)
            if result == .needsFullSync { realtime.requestState(state.request) }
            else if result == .applied { chat?.reconcile(push.data.snapshot); synchronizeSelection(); status = "Live"; detail = "Socket.IO state is current." }
        case .failed: startPolling()
        }
    }
    private func beginRealtimeAttempt(client: APIClient) {
        guard candidate == nil, promotion == nil, connected, !syncInterrupted, !state.needsFullSync else { return }
        let generation = generation, id = UUID()
        candidate = RealtimeHandoff(context: state.context, sourceGeneration: state.generation)
        socketID = id; realtimeRetryNotice = false
        status = "Checking realtime"; detail = "Polling keeps your state current while realtime reconnects."
        promotion = Task {
            do {
                let session = try await client.refreshSocketSession()
                try Task.checkCancellation()
                guard generation == self.generation, socketID == id, let candidate else { return }
                installRealtimeHandler(id: id, generation: generation)
                realtime.connect(session: session, request: candidate.request)
                // Includes connect, handler acknowledgement, and the first full state.
                var timeout: Duration = .seconds(20)
                #if DEBUG
                if usesFixture { timeout = .seconds(10) }
                #endif
                try await Task.sleep(for: timeout)
                guard generation == self.generation, socketID == id else { return }
                endRealtimeAttempt()
            } catch {
                guard generation == self.generation, socketID == id, !Task.isCancelled else { return }
                var policy = PollRecoveryPolicy()
                if case .retry = policy.failure(error) { endRealtimeAttempt() }
                else { fail(error) }
            }
        }
    }
    private func cancelRealtimeAttempt() {
        promotion?.cancel(); promotion = nil; candidate = nil; socketID = nil
        realtime.disconnect()
    }
    private func endRealtimeAttempt() {
        cancelRealtimeAttempt(); realtimeRetryNotice = true
        status = "Polling"; detail = "Realtime retry did not complete. Polling keeps your state current."
    }
    private func startPolling() {
        guard polling == nil, connected, !backgrounded, let client else { return }
        cancelRealtimeAttempt()
        let generation = self.generation, pollingID = UUID()
        self.pollingID = pollingID; realtimeRetryNotice = false
        state.invalidateForRecovery()
        recoveryStopped = false
        status = "Polling"; detail = "Realtime unavailable. Refreshing while this app is open."
        polling = Task {
            var recovery = PollRecoveryPolicy()
            var schedule = RealtimeRetrySchedule()
            let started = ContinuousClock.now
            defer { if generation == self.generation, pollingID == self.pollingID { polling = nil } }
            while !Task.isCancelled {
                let request = state.request
                let stateGeneration = state.generation
                let full = state.needsFullSync
                do {
                    let snapshot = try await client.poll(request)
                    try Task.checkCancellation()
                    guard generation == self.generation else { return }
                    let result = state.apply(snapshot:snapshot,generation:stateGeneration,full:full)
                    if result == .applied {
                        recovery.reset(); syncInterrupted = false
                        if let identity = activeIdentity { await saveAuthentication(client, identity: identity, generation: generation) }
                        guard generation == self.generation, !Task.isCancelled else { return }
                        chat?.resume(api:client); chat?.reconcile(snapshot); synchronizeSelection()
                        if candidate == nil && !state.needsFullSync {
                            status = "Polling"
                            detail = realtimeRetryNotice ? "Realtime retry did not complete. Polling keeps your state current." : "State is current. Refreshing while this app is open."
                        }
                        var elapsed = started.duration(to: .now)
                        var shouldAttempt = true
                        #if DEBUG
                        if usesFixture {
                            shouldAttempt = ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--synthetic-realtime-") })
                            elapsed *= 5 // Deterministic UI fixtures exercise the same schedule faster.
                        }
                        #endif
                        if shouldAttempt, candidate == nil, !state.needsFullSync, schedule.reserve(at: elapsed) {
                            beginRealtimeAttempt(client: client)
                        }
                    } else if result == .needsFullSync && full {
                        throw ClientError.incompatiblePayload
                    }
                    try await Task.sleep(for:.seconds(2))
                } catch {
                    guard generation == self.generation, !Task.isCancelled else { return }
                    // Security failures invalidate this connection even if chat selection changed.
                    if candidate != nil { cancelRealtimeAttempt() }
                    switch recovery.failure(error) {
                    case .retry(let delay):
                        if !syncInterrupted { chat?.suspend() }
                        syncInterrupted = true; state.invalidateForRecovery()
                        status = "Reconnecting"
                        detail = "Connection interrupted. Retry \(recovery.attempts) of 4. You can keep editing your draft; sending waits for current server state."
                        do { try await Task.sleep(for:delay) } catch { return }
                    case .paused:
                        syncInterrupted = true; recoveryStopped = true
                        status = "Sync paused"
                        detail = "Automatic connection retries stopped. Retry sync or disconnect. Drafts stay here; no messages are resent."
                        return
                    case .stop:
                        fail(error); return
                    }
                }
            }
        }
    }
    func retrySync() {
        guard connected, recoveryStopped, polling == nil else { return }
        startPolling()
    }
    func select(_ context: String?) {
        guard connected || demo else { return }
        invalidateJev()
        if candidate != nil { cancelRealtimeAttempt() }
        if let context { subagentDiscovery.acknowledge(child:context) }
        chat?.select(context)
        state.select(context: context)
        if connected && !syncInterrupted {
            status = "Synchronizing"; detail = "Refreshing the selected chat before sending."
        }
        if polling == nil && !demo { realtime.requestState(state.request) }
    }
    private func synchronizeSelection() {
        guard state.context != chat?.selectedContext else { return }
        if candidate != nil { cancelRealtimeAttempt() }
        state.select(context: chat?.selectedContext)
        if connected && !syncInterrupted {
            status = "Synchronizing"; detail = "Refreshing the selected chat before sending."
        }
        if polling == nil && !demo { realtime.requestState(state.request) }
    }
    func send() async {
        guard canSubmit, let chat else { return }
        preparingJevSend = true
        defer { preparingJevSend = false }
        let sendGeneration = generation, sendRevision = jevRevision, initialContext = chat.selectedContext
        let baseline = state.logs, before = Set(chat.deliveries.map(\.id))
        let richEnabled = DisplayPreferences.store.object(forKey:"richReplies") as? Bool ?? true
        let key: String?
        if richEnabled, let profile = jevProfile { key = try? await jevSettingsStore().keyIfEnabled(for:profile) }
        else { key = nil }
        guard generation == sendGeneration, jevRevision == sendRevision, self.chat === chat,
              chat.selectedContext == initialContext, connected || demo else { return }
        let context = state.contexts.first { $0["id"]?.string == chat.selectedContext }
        let busy = agentIsRunning
        var hasQueue = false
        if case .array(let queue) = context?["message_queue"] { hasQueue = !queue.isEmpty }
        if let client {
            chat.resume(api:GenerativeChatAPI(base:client,enabled:richEnabled,jev:key != nil))
        }
        let mode = SendMode(preference: DisplayPreferences.store.string(forKey: "sendMode"))
        await chat.send(mode: mode, isBusy: busy, hasQueue: hasQueue)
        guard self.chat === chat, connected || demo else { return }
        synchronizeSelection()
        guard sendGeneration == generation, sendRevision == jevRevision, let key, let context = chat.selectedContext,
              chat.deliveries.contains(where:{ !before.contains($0.id) && [.accepted,.queued].contains($0.status) }) else { return }
        pendingJev = (context,baseline,key)
        updateJevReplies()
    }
    func disconnect() {
        resetSubagentDiscovery()
        invalidateJev()
        clearSavedAuthentication()
        activeIdentity = nil; restoredSession = false; restorationPending = false
        chat?.suspend()
        if let client { Task { await client.disconnect() } }
        password = ""; credentialLoaded = false; profileBusy = false
        syncInterrupted = false; recoveryStopped = false
        generation = UUID(); operation?.cancel(); polling?.cancel(); operation = nil; polling = nil
        pollingID = UUID(); cancelRealtimeAttempt()
        client = nil; connecting = false; connected = false; demo = false
        state = SyncReducer(); status = "Not connected"
    }
    func suspend() {
        invalidateJev()
        backgrounded = true
        password = ""; credentialLoaded = false
        // iOS suspends transports; the server session and server-side agent remain alive.
        // Keep the reducer and generated surfaces mounted so foreground return preserves them.
        generation = UUID(); operation?.cancel(); operation = nil
        polling?.cancel(); polling = nil; pollingID = UUID(); cancelRealtimeAttempt()
        if connected {
            chat?.suspend(); syncInterrupted = true; state.invalidateForRecovery()
            status = "Session saved"; detail = "Agent Zero continues on your server. Updates resume when you return."
        } else {
            restorationPending = connecting || restorationPending
            connecting = false; profileBusy = false
        }
    }
    private func fail(_ error: any Error) {
        disconnect(); status = "Connection needs attention"
        if error is PersistenceError {
            status = "Saved drafts unavailable"
            detail = "Unlock this device and reconnect to retry. Existing local data has not been replaced. If this continues, keep the app installed to preserve its saved data."
        } else { detail = (error as? ClientError)?.errorDescription ?? "The connection failed. Check the address, network, and certificate." }
    }
    func loadDemo() {
        disconnect(); demo = true
        chat = ChatSession(api: PreviewChatAPI(timeout: ProcessInfo.processInfo.arguments.contains("--synthetic-send-timeout")))
        chat?.select("synthetic-chat")
        guard let url = Bundle.main.url(forResource: "full", withExtension: "json"),
              let data = try? Data(contentsOf: url), let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        let generation = state.select(context: "synthetic-chat")
        _ = state.apply(snapshot: snapshot, generation: generation, full: true)
        status = "Synthetic preview"; detail = "Local fixture only. No server connection or live verification."
    }
}

/// Explicit synthetic preview: never connects to or mutates a server.
private actor PreviewChatAPI: ChatAPI {
    let timeout: Bool
    init(timeout: Bool) { self.timeout = timeout }
    func createChat(id: String) async throws -> String { id }
    func sendAttachments(context: String, text: String, messageID: String, queued: Bool, attachments: [ChatAttachment]) async throws {
        if timeout { throw URLError(.timedOut) }
    }
    func sendText(context: String, text: String, messageID: String, queued: Bool) async throws {
        if timeout { throw URLError(.timedOut) }
    }
}


extension SpikeModel {
    var jevProfile: ProfileIdentity? { activeIdentity }
    func jevSettingsStore() -> JevSettingsStore {
        if let jevStore { return jevStore }
        let service = "local.agentzero.jev.v1" + (usesFixture ? ".test." + testNamespace.uuidString : "")
        let store = JevSettingsStore(credentials:KeychainCredentialStore(service:service))
        jevStore = store; return store
    }
    func invalidateJev() {
        jevRevision = UUID(); pendingJev = nil; jevCoordinator?.cancel()
    }
    private func updateJevReplies() {
        guard let profile = activeIdentity, let context = chat?.selectedContext,
              state.context == context, let epoch = state.logGUID, !state.needsFullSync else { return }
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        guard let identity = try? encoder.encode(profile),
              let scopeData = try? encoder.encode([String(decoding:identity,as:UTF8.self),context,epoch]) else { return }
        let scope = String(decoding:scopeData,as:UTF8.self)
        if let pending = pendingJev, pending.context == context {
            if jevCoordinator == nil {
                guard let directory = try? storageDirectory().appendingPathComponent("JevAttempts") else { pendingJev = nil; return }
                var chooser: any JevChoosing = JevClient()
                #if DEBUG
                if usesFixture { chooser = JevPreviewChooser() }
                #endif
                jevCoordinator = JevCoordinator(chooser:chooser,journal:JevAttemptJournal(directory:directory))
            }
            jevCoordinator?.arm(scope:scope,baseline:pending.baseline,key:pending.key)
            pendingJev = nil
        }
        jevCoordinator?.observe(state.logs,scope:scope)
    }
}
