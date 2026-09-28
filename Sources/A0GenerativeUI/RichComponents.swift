import Foundation
import A2UISwiftCore

public struct ForecastContent: Decodable, Sendable {
    public struct Day: Decodable, Sendable { public let label:String; public let high:Double; public let low:Double; public let condition:String; public let icon:String }
    public let location:String
    public let updatedAt:String
    public let unit:String
    public let temperature:Double
    public let condition:String
    public let icon:String
    public let days:[Day]
    public let sourceURL:String
}
public struct CarouselContent: Decodable, Sendable {
    public struct Item: Decodable, Sendable { public let url:String; public let title:String; public let sourceURL:String }
    public let title:String
    public let images:[Item]
}
public struct ChartContent: Decodable, Sendable {
    public struct Point: Decodable, Sendable { public let label:String; public let value:Double; public let series:String? }
    public let title:String
    public let kind:String
    public let yLabel:String
    public let points:[Point]
    public let sourceURL:String?
}
public enum RichImagePolicy {
    public static func url(_ string:String) -> URL? {
        guard string.utf8.count <= 4096, let c = URLComponents(string:string), c.scheme == "https", c.user == nil, c.password == nil,
              c.port == nil || c.port == 443, let host = c.host?.lowercased(), host.contains("."),
              !host.contains(":"), !host.hasSuffix("."), !host.allSatisfy({ $0.isNumber || $0 == "." }),
              ![".localhost",".local",".internal",".lan",".home",".test",".invalid"].contains(where:host.hasSuffix),
              host != "localhost", !host.hasPrefix("127."), let url = c.url else { return nil }
        return url
    }
}
extension GeneratedDocument {
    static func decodeRich<T:Decodable>(_ type:T.Type,component:RawComponent) throws -> T {
        try JSONDecoder().decode(type,from:JSONEncoder().encode(component.properties))
    }
    static func validateRich(_ c:RawComponent) throws {
        switch c.component {
        case "Forecast":
            let p = try decodeRich(ForecastContent.self,component:c)
            guard ["C","F"].contains(p.unit), p.temperature.isFinite, abs(p.temperature) < 300, p.days.count <= 10,
                  !p.location.isEmpty, RichImagePolicy.url(p.sourceURL) != nil,
                  p.days.allSatisfy({$0.high.isFinite && $0.low.isFinite && $0.high >= $0.low && abs($0.high) < 300 && abs($0.low) < 300}) else { throw GeneratedUIError.invalid }
        case "ImageCarousel":
            let p = try decodeRich(CarouselContent.self,component:c)
            guard (1...10).contains(p.images.count), p.images.allSatisfy({ !$0.title.isEmpty && RichImagePolicy.url($0.url) != nil && RichImagePolicy.url($0.sourceURL) != nil }) else { throw GeneratedUIError.invalid }
        case "Chart":
            let p = try decodeRich(ChartContent.self,component:c)
            guard ["line","bar","area"].contains(p.kind), (1...128).contains(p.points.count),
                  p.sourceURL == nil || RichImagePolicy.url(p.sourceURL!) != nil,
                  p.points.allSatisfy({!$0.label.isEmpty && $0.value.isFinite && abs($0.value) < 1e12}) else { throw GeneratedUIError.invalid }
        default: break
        }
    }
}
