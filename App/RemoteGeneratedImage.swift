import SwiftUI
import ImageIO
import A0GenerativeUI

struct RemoteGeneratedImage: View {
    @Environment(\.a0Theme) private var theme
    let url:String
    let title:String
    @State private var image:UIImage?
    @State private var failed = false
    @State private var retry = 0
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ZStack {
            theme.canvas
            if let image { Image(uiImage:image).resizable().scaledToFit().accessibilityLabel(title) }
            else if synthetic {
                VStack(spacing:12) { Image(systemName:"photo.on.rectangle.angled").font(.largeTitle); Text("Synthetic image preview").font(.caption) }.foregroundStyle(theme.muted)
            } else if failed {
                VStack(spacing:12) {
                    Label("Image unavailable",systemImage:"photo.badge.exclamationmark")
                    Button("Retry",systemImage:"arrow.clockwise") { retry += 1 }
                }.foregroundStyle(theme.muted)
            } else { ProgressView("Loading image…") }
        }.task(id:"\(url)-\(retry)-\(scenePhase == .active)") {
            guard !synthetic, scenePhase == .active else { return }
            failed = false
            do {
                let data = try await ImageDownloads.shared.load(url)
                try Task.checkCancellation()
                guard let source = CGImageSourceCreateWithData(data as CFData,nil),
                      let thumbnail = CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:1200,kCGImageSourceCreateThumbnailWithTransform:true] as CFDictionary) else { throw URLError(.cannotDecodeContentData) }
                image = UIImage(cgImage:thumbnail)
            } catch { if !Task.isCancelled { failed = true } }
        }
    }
    private var synthetic:Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--synthetic-rich-ui")
        #else
        false
        #endif
    }
}
