import Foundation
import A2UISwiftCore

public struct MetricContent: Decodable,Sendable {
    public let title:String
    public let value:String
    public let unit:String?
    public let change:String?
    public let trend:String?
    public let sourceURL:String?
}
public struct DataTableContent: Decodable,Sendable {
    public let title:String
    public let columns:[String]
    public let rows:[[String]]
    public let sourceURL:String?
}
public struct TimelineContent: Decodable,Sendable {
    public struct Item: Decodable,Sendable {
        public let id:String
        public let title:String
        public let time:String?
        public let detail:String?
        public let state:String?
    }
    public let title:String
    public let items:[Item]
    public let sourceURL:String?
}
public struct ChecklistContent: Decodable,Sendable { public let title:String; public let children:[String] }

extension GeneratedDocument {
    static func validateExpanded(_ c:RawComponent) throws {
        func text(_ value:String,_ limit:Int = 160)->Bool { !value.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && value.utf8.count <= limit }
        func optionalText(_ value:String?,_ limit:Int = 160)->Bool { value == nil || text(value!,limit) }
        func source(_ value:String?)->Bool { value == nil || RichImagePolicy.url(value!) != nil }
        switch c.component {
        case "Metric":
            let p = try decodeRich(MetricContent.self,component:c)
            guard text(p.title), text(p.value,80), optionalText(p.unit,40), optionalText(p.change),
                  p.trend == nil || ["up","down","neutral"].contains(p.trend!), source(p.sourceURL) else { throw GeneratedUIError.invalid }
        case "DataTable":
            let p = try decodeRich(DataTableContent.self,component:c)
            guard text(p.title), (1...6).contains(p.columns.count), p.columns.allSatisfy({text($0,80)}),
                  Set(p.columns).count == p.columns.count, (1...50).contains(p.rows.count), source(p.sourceURL),
                  p.rows.allSatisfy({$0.count == p.columns.count && $0.allSatisfy({$0.utf8.count <= 512})}) else { throw GeneratedUIError.invalid }
        case "Timeline":
            let p = try decodeRich(TimelineContent.self,component:c)
            guard text(p.title), (1...30).contains(p.items.count), Set(p.items.map(\.id)).count == p.items.count, source(p.sourceURL),
                  p.items.allSatisfy({ validID($0.id) && text($0.title) && optionalText($0.time,80) && optionalText($0.detail,1024)
                    && ($0.state == nil || ["pending","current","complete"].contains($0.state!)) }) else { throw GeneratedUIError.invalid }
        case "Checklist":
            let p = try decodeRich(ChecklistContent.self,component:c)
            guard text(p.title), (1...21).contains(p.children.count), Set(p.children).count == p.children.count else { throw GeneratedUIError.invalid }
        default: throw GeneratedUIError.unsupported
        }
    }
}
