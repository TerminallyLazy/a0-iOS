import SwiftUI
import ImageIO
import A0Core

/// Capture the owner at construction, so a reused row cannot display another chat's private image.
@MainActor struct BrowserMediaScope {
    let model: SpikeModel
    let generation: UUID
    let context: String
    let logGUID: String?
    init(model: SpikeModel) {
        self.model = model; generation = model.connectionGeneration
        context = model.state.context ?? ""; logGUID = model.state.logGUID
    }
    var id: String { generation.uuidString + "|" + context + "|" + (logGUID ?? "") }
    var isCurrent: Bool {
        generation == model.connectionGeneration && context == (model.state.context ?? "") && logGUID == model.state.logGUID
    }
    func load(_ screenshot: BrowserScreenshot) async throws -> Data {
        guard isCurrent, let client = model.controlClient else { throw ClientError.disconnected }
        let data = try await client.browserScreenshot(screenshot)
        try Task.checkCancellation()
        guard isCurrent else { throw ClientError.disconnected }
        return data
    }
}

private struct DecodedBrowserImage: @unchecked Sendable { let image: CGImage }

struct BrowserScreenshotView: View {
    let screenshot: BrowserScreenshot
    let scope: BrowserMediaScope
    var onOpen: () -> Void = {}
    @State private var image: CGImage?
    @State private var failed = false
    @State private var preview = false
    @State private var attempt = 0
    @Environment(\.scenePhase) private var scenePhase
    private var taskID: String { scope.id + "|" + screenshot.id + "|" + String(attempt) + "|" + String(describing:scenePhase) }

    var body: some View {
        VStack(alignment:.leading,spacing:0) {
            Button {
                guard image != nil else { return }
                onOpen(); preview = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius:12).fill(Color("A0Canvas"))
                    if let image {
                        Image(decorative:image,scale:1).resizable().scaledToFit()
                    } else if failed {
                        VStack(spacing:8) {
                            Image(systemName:"photo.badge.exclamationmark").font(.title2)
                            Text("Screenshot unavailable").font(.caption)
                        }.foregroundStyle(Color.a0Supporting)
                    } else {
                        ProgressView().accessibilityLabel("Loading browser screenshot")
                    }
                }.frame(height:160).frame(maxWidth:.infinity).clipped()
            }.buttonStyle(.plain).disabled(image == nil)
                .accessibilityLabel("Browser screenshot")
                .accessibilityHint("Opens a larger preview")
                .accessibilityIdentifier("browserScreenshot")
            HStack(spacing:8) {
                Image(systemName:"globe").foregroundStyle(Color.a0Supporting).accessibilityHidden(true)
                Text("Browser capture").font(.caption.weight(.medium))
                Spacer()
                if failed {
                    Button { attempt += 1 } label: {
                        Label("Retry",systemImage:"arrow.clockwise").font(.caption).frame(minWidth:44,minHeight:44)
                    }
                } else {
                    Image(systemName:"arrow.up.left.and.arrow.down.right").font(.caption).foregroundStyle(Color.a0Supporting).accessibilityHidden(true)
                }
            }.padding(.horizontal,12).frame(minHeight:44)
        }
        .background(Color("A0Canvas"),in:RoundedRectangle(cornerRadius:12))
        .clipShape(RoundedRectangle(cornerRadius:12))
        .overlay(RoundedRectangle(cornerRadius:12).strokeBorder(Color.a0Supporting.opacity(0.2),lineWidth:0.5))
        .popover(isPresented:$preview) {
            VStack(spacing:12) {
                HStack {
                    Label("Browser capture",systemImage:"globe").font(.subheadline.weight(.semibold))
                    Spacer()
                    Button { preview = false } label: {
                        Image(systemName:"xmark").frame(width:44,height:44)
                    }.accessibilityLabel("Close screenshot preview")
                }
                if let image {
                    Image(decorative:image,scale:1).resizable().scaledToFit().frame(maxHeight:440)
                        .accessibilityLabel("Browser screenshot preview")
                }
            }.padding(12).frame(idealWidth:560,maxWidth:560)
                .presentationCompactAdaptation(.popover)
                .accessibilityIdentifier("browserScreenshotPreview")
        }
        .task(id:taskID) {
            image = nil; failed = false; preview = false
            guard scenePhase == .active else { return }
            do {
                let data = try await scope.load(screenshot)
                let decoded = try await Task.detached(priority:.utility) {
                    try Task.checkCancellation()
                    guard let source = CGImageSourceCreateWithData(data as CFData,[kCGImageSourceShouldCache:false] as CFDictionary),
                          let properties = CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],
                          let width = properties[kCGImagePropertyPixelWidth] as? Int,
                          let height = properties[kCGImagePropertyPixelHeight] as? Int,
                          width > 0, height > 0, width <= 16000, height <= 16000,
                          width * height <= 40_000_000,
                          let image = CGImageSourceCreateThumbnailAtIndex(source,0,[
                            kCGImageSourceCreateThumbnailFromImageAlways:true,
                            kCGImageSourceThumbnailMaxPixelSize:1400,
                            kCGImageSourceCreateThumbnailWithTransform:true,
                            kCGImageSourceShouldCacheImmediately:true
                          ] as CFDictionary) else { throw ClientError.unexpectedResponse }
                    return DecodedBrowserImage(image:image)
                }.value
                try Task.checkCancellation()
                guard scope.isCurrent else { return }
                image = decoded.image
            } catch is CancellationError { }
            catch { if scope.isCurrent && !Task.isCancelled { failed = true } }
        }
        .onDisappear { image = nil; preview = false }
    }
}
