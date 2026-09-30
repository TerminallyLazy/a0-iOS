import SwiftUI
import ImageIO
import A0Core
import A0GenerativeUI

private struct DecodedPluginThumbnail: @unchecked Sendable { let image:CGImage }

struct PluginThumbnailView:View {
    @Environment(\.a0Theme) private var theme
    let model:SpikeModel
    let reference:PluginThumbnail?
    var size:CGFloat = 64
    @Environment(\.scenePhase) private var scenePhase
    @State private var image:CGImage?
    private var taskID:String { model.connectionGeneration.uuidString + String(describing:reference) + String(describing:scenePhase) }
    var body:some View {
        ZStack {
            RoundedRectangle(cornerRadius:12).fill(theme.input)
            if let image { Image(decorative:image,scale:1).resizable().scaledToFit().padding(3) }
            else { Image(systemName:"puzzlepiece.extension").font(.system(size:26)).foregroundStyle(theme.muted) }
        }
        .frame(width:size,height:size).clipShape(RoundedRectangle(cornerRadius:12))
        .accessibilityHidden(true)
        .task(id:taskID) {
            image = nil
            let generation = model.connectionGeneration
            guard scenePhase == .active,model.canSubmit,let reference else { return }
            do {
                let data:Data
                if reference.serverPath != nil,let client = model.controlClient { data = try await client.pluginThumbnail(reference) }
                else if let url = reference.remoteURL { data = try await ImageDownloads.shared.load(url.absoluteString) }
                else { return }
                let decoded = try await Task.detached(priority:.utility) {
                    try Task.checkCancellation()
                    guard let source = CGImageSourceCreateWithData(data as CFData,[kCGImageSourceShouldCache:false] as CFDictionary),
                          let properties = CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],
                          let width = properties[kCGImagePropertyPixelWidth] as? Int,
                          let height = properties[kCGImagePropertyPixelHeight] as? Int,
                          width > 0,height > 0,width <= 16000,height <= 16000,width * height <= 40_000_000,
                          let image = CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:384,kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceShouldCacheImmediately:true] as CFDictionary) else { throw ClientError.unexpectedResponse }
                    return DecodedPluginThumbnail(image:image)
                }.value
                try Task.checkCancellation()
                guard generation == model.connectionGeneration,scenePhase == .active else { return }
                image = decoded.image
            } catch { /* Missing artwork keeps the consistent plugin placeholder. */ }
        }
        .onDisappear { image = nil }
    }
}
