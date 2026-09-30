import Foundation

public enum MediaKind:String,Sendable { case audio, video
    public var byteLimit:Int { self == .audio ? 32 * 1_048_576 : 100 * 1_048_576 }
    func fileExtension(for mime:String)->String? {
        switch (self,mime) {
        case (.audio,"audio/mpeg"): "mp3"
        case (.audio,"audio/mp4"),(.audio,"audio/x-m4a"): "m4a"
        case (.audio,"audio/aac"): "aac"
        case (.audio,"audio/wav"),(.audio,"audio/x-wav"): "wav"
        case (.video,"video/mp4"): "mp4"
        case (.video,"video/quicktime"): "mov"
        default: nil
        }
    }
}
public struct MediaContent:Decodable,Sendable {
    public let title:String
    public let url:String
    public let transcript:String?
    public let sourceURL:String?
    func validate() throws {
        guard !title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty, title.utf8.count <= 160,
              RichImagePolicy.url(url) != nil, (transcript?.utf8.count ?? 0) <= 8192,
              sourceURL.map({RichImagePolicy.url($0) != nil}) ?? true else { throw GeneratedUIError.invalid }
    }
}
