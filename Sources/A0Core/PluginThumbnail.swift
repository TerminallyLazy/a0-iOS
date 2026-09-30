import Foundation

/// Installed artwork is restricted to the plugin's declared raster thumbnail path.
public struct PluginThumbnail: Sendable, Hashable {
    public let serverPath: String?
    public let remoteURL: URL?
    public static func reference(_ value:String,pluginID:String) -> Self? {
        guard (try? PluginIdentity.validate(pluginID)) != nil else { return nil }
        let paths = ["png","jpg","jpeg","gif","webp"].map { "/plugins/\(pluginID)/webui/thumbnail.\($0)" }
        if paths.contains(value) { return Self(serverPath:value,remoteURL:nil) }
        guard let url = URL(string:value),url.scheme == "https",let host = url.host,!host.isEmpty,
              url.user == nil,url.password == nil,url.fragment == nil else { return nil }
        return Self(serverPath:nil,remoteURL:url)
    }
}

extension InstalledPlugin {
    public var thumbnail:PluginThumbnail? {
        guard let value = fields["thumbnail_url"]?.string,
              let reference = PluginThumbnail.reference(value,pluginID:id),reference.serverPath != nil else { return nil }
        return reference
    }
}
extension PluginHubEntry {
    public var thumbnail:PluginThumbnail? {
        if let value = fields["thumbnail"]?.string,!value.isEmpty { return PluginThumbnail.reference(value,pluginID:id) }
        guard let source,source.host == "github.com" else { return nil }
        var parts = source.path.split(separator:"/").map(String.init)
        guard parts.count == 2 else { return nil }
        if parts[1].hasSuffix(".git") { parts[1].removeLast(4) }
        return PluginThumbnail.reference("https://raw.githubusercontent.com/\(parts.joined(separator:"/"))/main/thumbnail.png",pluginID:id)
    }
}
extension APIClient {
    public func pluginThumbnail(_ reference:PluginThumbnail) async throws -> Data {
        guard let path = reference.serverPath else { throw ClientError.incompatiblePayload }
        let session = try socketSession()
        var url = URLComponents(url:session.origin.url,resolvingAgainstBaseURL:false)!
        url.path = path
        var request = URLRequest(url:url.url!,cachePolicy:.reloadIgnoringLocalCacheData,timeoutInterval:15)
        request.setValue(session.cookieHeader,forHTTPHeaderField:"Cookie")
        request.setValue(session.origin.header,forHTTPHeaderField:"Origin")
        request.setValue("image/png, image/jpeg, image/gif, image/webp",forHTTPHeaderField:"Accept")
        let response = try await boundedImageRequest(request,maximumBytes:4_194_304)
        try Task.checkCancellation()
        return try BrowserScreenshot.validate(response)
    }
}
