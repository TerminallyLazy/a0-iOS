import Foundation
import Testing
@testable import A0Core

@Suite struct ProjectTests {
    @Test func editingRetainsServerExtensionDataAndMaskedSecrets() throws {
        let original: [String: JSONValue] = ["name":.string("research"), "title":.string("Research"), "secrets":.string("KEY=***"), "plugin":.object(["nested":.array([.number(1)])]), "file_structure":.object(["enabled":.bool(true), "plugin_setting":.string("keep")])]
        var document = ProjectDocument(fields: original)
        document.title = "Field notes"
        var structure = document.fileStructure
        structure["max_depth"] = .number(4)
        document.fileStructure = structure
        let payload = try ProjectOperation.update(document).payload()
        guard case .object(let sent) = payload["project"] else { Issue.record("Missing project"); return }
        #expect(sent["plugin"] == original["plugin"])
        #expect(sent["secrets"] == original["secrets"])
        #expect(document.fileStructure["plugin_setting"] == .string("keep"))
        #expect(sent["title"] == .string("Field notes"))
    }

    @Test func projectsUseServerNamesAndScopedActivation() throws {
        #expect(try ProjectOperation.activate(name:"research",context:"chat").payload() == ["action":.string("activate"),"name":.string("research"),"context_id":.string("chat")])
        #expect(try ProjectOperation.deactivate(context:"chat").payload()["context_id"] == .string("chat"))
        for name in ["", ".", "..", "../escape", "nested/project", "nested\\project", "bad\nname"] {
            #expect(throws: ProjectError.invalidName) { try ProjectOperation.delete(name:name).payload() }
        }
        #expect(throws: ClientError.incompatiblePayload) { try ProjectOperation.activate(name:"research",context:"").payload() }
    }

    @Test func cloneTokenIsTransientAndCredentialsAreNotAllowedInURL() throws {
        var document = ProjectDocument(name:"research",title:"Research")
        document.gitURL = "https://github.com/example/research.git"
        let payload = try ProjectOperation.clone(document,gitToken:"synthetic-token").payload()
        guard case .object(let sent) = payload["project"] else { Issue.record("Missing project"); return }
        #expect(sent["git_token"] == .string("synthetic-token"))
        #expect(document.fields["git_token"] == nil)
        document.gitURL = "https://token@github.com/example/research.git"
        #expect(throws: ProjectError.invalidGitURL) { try ProjectOperation.clone(document,gitToken:"").payload() }
    }

    @Test func responseEnvelopesAreValidatedAndErrorsSanitized() throws {
        #expect(throws: ProjectError.serverRejected) { try ProjectOperation.list.result(Data(#"{"ok":false,"error":"private file path and token"}"#.utf8)) }
        #expect(!ProjectError.serverRejected.localizedDescription.contains("token"))
        #expect(throws: ClientError.incompatiblePayload) { try ProjectOperation.list.result(Data(#"{"ok":true,"data":[{"title":"Missing identity"}]}"#.utf8)) }
        #expect(throws: ClientError.incompatiblePayload) { try ProjectOperation.delete(name:"a").result(Data(#"{"ok":true,"data":"other"}"#.utf8)) }
        #expect(try ProjectOperation.activate(name:"a",context:"c").result(Data(#"{"ok":true,"data":null}"#.utf8)) == .activated)
        #expect(try ProjectOperation.fileStructure(name:"a",settings:nil).result(Data(#"{"ok":true,"data":"project/\n file.txt"}"#.utf8)) == .fileStructure("project/\n file.txt"))
    }

    @Test func summariesDecodeColorsAndContextProjection() throws {
        let result = try ProjectOperation.list.result(Data(##"{"ok":true,"data":[{"name":"a","title":"Alpha","description":"Notes","color":"#002975ff"}]}"##.utf8))
        #expect(result == .list([ProjectSummary(name:"a",title:"Alpha",description:"Notes",color:"#002975ff")]))
        let summary = ProjectSummary(context:["project":.object(["name":.string("a"),"title":.string("Alpha"),"color":.string("#002975ff")])])
        #expect(summary?.color == "#002975ff")
        #expect(ProjectSummary(context:["project":.null]) == nil)
        #expect(ProjectSummary.colors.contains("#002975ff"))
    }

    @Test func malformedProjectIdentitiesNeverBecomeEditable() throws {
        #expect(throws: ClientError.incompatiblePayload) { try ProjectOperation.list.result(Data(#"{"ok":true,"data":[{"name":"../outside"}]}"#.utf8)) }
        #expect(throws: ClientError.incompatiblePayload) { try ProjectOperation.create(ProjectDocument(name:"new",title:"New")).result(Data(#"{"ok":true,"data":{"name":"../outside"}}"#.utf8)) }
        #expect(throws: ProjectError.invalidName) { try ProjectOperation.delete(name:" .. ").payload() }
    }

    @Test func authenticatedRequestsNeverRetryAndClearRejectedSession() async throws {
        let transport = ScriptTransport(loginResponses() + [HTTPResponse(data:Data(),status:503), HTTPResponse(data:Data(),status:403)])
        let client = APIClient(origin:try ServerOrigin("https://server.test"),transport:transport)
        await #expect(throws:ClientError.requiresLogin) { try await client.projects(.list) }
        #expect(await transport.requests.isEmpty)
        try await client.connect(username:"fixture",password:"fixture")
        await #expect(throws:ClientError.httpStatus(503)) { try await client.projects(.create(ProjectDocument(name:"new",title:"New"))) }
        #expect(await transport.requests.count == 4)
        let request = try #require(await transport.requests.last)
        #expect(request.url?.path == "/api/projects")
        #expect(request.value(forHTTPHeaderField:"X-CSRF-Token") == "synthetic-csrf")
        #expect(request.value(forHTTPHeaderField:"Origin") == "https://server.test")
        await #expect(throws:ClientError.csrfRejected) { try await client.projects(.list) }
        await #expect(throws:ClientError.requiresLogin) { try await client.projects(.list) }
        #expect(await transport.requests.count == 5)
    }
}
