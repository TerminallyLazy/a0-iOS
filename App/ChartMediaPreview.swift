#if DEBUG
import Foundation
import AVFoundation
import CoreVideo
import A0GenerativeUI

/// Entirely local synthetic catalog and playable media; no external URL is requested.
enum ChartMediaPreview {
    static func surface(kind:String) throws -> String {
        var node:[String:Any]
        if ["audio","video"].contains(kind) {
            node = ["id":"root","component":kind == "audio" ? "AudioPlayer":"Video","title":"Synthetic " + kind,"url":"https://media.example.com/clip","transcript":"A generated test clip. No conversation or microphone content."]
        } else {
            let numeric = ["scatter","bubble","histogram","range"].contains(kind)
            let points:[[String:Any]] = [
                ["label":"Observation A","value":4,"x":2,"size":2,"lower":1,"upper":5,"row":"North"],
                ["label":"Observation B","value":8,"x":6,"size":8,"lower":5,"upper":9,"row":"North"],
                ["label":"Observation C","value":12,"x":10,"size":4,"lower":9,"upper":13,"row":"North"]
            ]
            var displayed = points
            if ["groupedBar","stackedBar","stackedArea","line","area"].contains(kind) {
                displayed = points.map { var p = $0; p["series"] = "Current"; return p } + points.map { var p = $0; p["series"] = "Previous"; p["value"] = ($0["value"] as! Int) / 2; return p }
            }
            if kind == "heatmap" { displayed += points.map { var p = $0; p["row"] = "South"; p["value"] = ($0["value"] as! Int) / 2; return p } }
            if !numeric { displayed = displayed.map { var p = $0; for key in ["x","size","lower","upper"] { p.removeValue(forKey:key) }; if kind != "heatmap" { p.removeValue(forKey:"row") }; return p } }
            if kind == "denseScatter" { displayed = (0..<128).map { ["label":"Observation \($0)","value":($0 * 13) % 41,"x":$0] } }
            node = ["id":"root","component":"Chart","title":"Synthetic " + kind,"kind":kind == "denseScatter" ? "scatter" : kind,"yLabel":"Observations (units)","xLabel":"Sample","sizeLabel":"Magnitude","points":displayed]
        }
        return String(decoding:try JSONSerialization.data(withJSONObject:[
            ["version":"v0.9","createSurface":["surfaceId":"mediacharts","catalogId":GeneratedDocument.richCatalogID]],
            ["version":"v0.9","updateComponents":["surfaceId":"mediacharts","components":[node]]]
        ],options:.sortedKeys),as:UTF8.self)
    }
}
extension GeneratedPlayback {
    static func fixture(kind:MediaKind) async throws -> GeneratedPlayback {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("a0-playback-fixture-" + UUID().uuidString).appendingPathExtension(kind == .audio ? "wav":"mov")
        do {
            if ProcessInfo.processInfo.arguments.contains("--synthetic-media-slow") { try await Task.sleep(for:.seconds(8)) }
            if ProcessInfo.processInfo.arguments.contains("--synthetic-media-invalid") {
                try Data("Not a media file".utf8).write(to:url)
                return GeneratedPlayback(fixtureURL:url)
            }
            if kind == .audio {
                let count = 16000 * (ProcessInfo.processInfo.arguments.contains("--synthetic-media-handoff") ? 32:8)
                var data = Data()
                func text(_ s:String) { data.append(contentsOf:s.utf8) }
                func number<T:FixedWidthInteger>(_ n:T) { var little = n.littleEndian; withUnsafeBytes(of:&little) { data.append(contentsOf:$0) } }
                text("RIFF"); number(UInt32(36+count*2)); text("WAVEfmt "); number(UInt32(16)); number(UInt16(1)); number(UInt16(1)); number(UInt32(16000)); number(UInt32(32000)); number(UInt16(2)); number(UInt16(16)); text("data"); number(UInt32(count*2)); data.append(Data(repeating:0,count:count*2))
                try data.write(to:url)
            } else {
                let writer = try AVAssetWriter(outputURL:url,fileType:.mov)
                let input = AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:320,AVVideoHeightKey:180])
                let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32ARGB,kCVPixelBufferWidthKey as String:320,kCVPixelBufferHeightKey as String:180])
                writer.add(input); writer.startWriting(); writer.startSession(atSourceTime:.zero)
                let frames = ProcessInfo.processInfo.arguments.contains("--synthetic-media-handoff") ? 64:16
                for frame in 0..<frames {
                    while !input.isReadyForMoreMediaData { try await Task.sleep(for:.milliseconds(10)) }
                    var buffer:CVPixelBuffer?
                    CVPixelBufferPoolCreatePixelBuffer(nil,adaptor.pixelBufferPool!,&buffer)
                    guard let buffer else { throw URLError(.cannotCreateFile) }
                    CVPixelBufferLockBaseAddress(buffer,[])
                    memset(CVPixelBufferGetBaseAddress(buffer),frame % 2 == 0 ? 50:120,CVPixelBufferGetDataSize(buffer))
                    CVPixelBufferUnlockBaseAddress(buffer,[])
                    guard adaptor.append(buffer,withPresentationTime:CMTime(value:Int64(frame),timescale:2)) else { throw URLError(.cannotCreateFile) }
                }
                input.markAsFinished(); await writer.finishWriting()
                guard writer.status == .completed else { throw URLError(.cannotCreateFile) }
            }
            return GeneratedPlayback(fixtureURL:url)
        } catch { try? FileManager.default.removeItem(at:url); throw error }
    }
}
#endif
