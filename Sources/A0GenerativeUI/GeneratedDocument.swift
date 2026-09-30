import Foundation
import A2UISwiftCore

public enum GeneratedUIError: Error { case unsupported, invalid, tooLarge }

/// A bounded, network-free subset of the SDK basic catalog. Validate the entire
/// self-contained reply before feeding anything to the renderer.
public struct GeneratedDocument {
    public static let components: Set<String> = ["Text","Row","Column","Card","Divider","Button","TextField","CheckBox","ChoicePicker","Slider","Forecast","ImageCarousel","Chart","Dashboard","Metric","DataTable","Timeline","Checklist","AudioPlayer","Video"]
    public static let richCatalogID = "agent-zero:mobile:v1"
    public let catalogID: String
    public let surfaceID: String
    public let messages: [A2uiMessage]
    public let deleted: Bool

    public static func validate(_ source: String) throws -> Self {
        guard source.utf8.count <= 65_536 else { throw GeneratedUIError.tooLarge }
        let data = Data(source.utf8)
        let raw = try JSONSerialization.jsonObject(with:data)
        var budget = 4096
        try bounded(raw,depth:0,budget:&budget)
        let messages = try JSONDecoder().decode([A2uiMessage].self,from:data)
        guard !messages.isEmpty, messages.count <= 32,
              case .createSurface(let create) = messages[0], validID(create.surfaceId),
              [basicCatalogId,richCatalogID].contains(create.catalogId), create.theme == nil, !create.sendDataModel else { throw GeneratedUIError.unsupported }
        var nodes: [String:RawComponent] = [:]
        var deleted = false
        for (index,message) in messages.enumerated() {
            guard !deleted else { throw GeneratedUIError.invalid }
            switch message {
            case .createSurface:
                guard index == 0 else { throw GeneratedUIError.invalid }
            case .updateComponents(let update):
                guard update.surfaceId == create.surfaceId, update.components.count <= 64,
                      Set(update.components.map(\.id)).count == update.components.count else { throw GeneratedUIError.invalid }
                for component in update.components {
                    guard validID(component.id), components.contains(component.component),
                          component.weight == nil || (component.weight! > 0 && component.weight! <= 100) else { throw GeneratedUIError.unsupported }
                    if ["Forecast","ImageCarousel","Chart","Dashboard","Metric","DataTable","Timeline","Checklist","AudioPlayer","Video"].contains(component.component), create.catalogId != richCatalogID { throw GeneratedUIError.unsupported }
                    try validateComponent(component)
                    nodes[component.id] = component
                }
                guard nodes.count <= 64 else { throw GeneratedUIError.tooLarge }
                // The SDK renders each update, not just the final state. Bound
                // intermediate graphs too, while allowing forward references.
                for key in nodes.keys {
                    var count = 0
                    try walk(key,nodes:nodes,ancestors:[],depth:0,count:&count,allowMissing:true)
                }
            case .updateDataModel(let update):
                guard update.surfaceId == create.surfaceId else { throw GeneratedUIError.invalid }
                try validatePath(update.path ?? "/")
            case .deleteSurface(let update):
                guard update.surfaceId == create.surfaceId else { throw GeneratedUIError.invalid }
                deleted = true
            }
        }
        // Check all nodes, even unreachable ones, before SDK tree construction.
        for key in nodes.keys {
            var count = 0
            try walk(key,nodes:nodes,ancestors:[],depth:0,count:&count)
        }
        for node in nodes.values where node.component == "Checklist" {
            let items = try children(node).compactMap { nodes[$0] }
            guard (1...20).contains(items.filter({$0.component == "CheckBox"}).count), items.filter({$0.component == "Button"}).count <= 1,
                  items.allSatisfy({["CheckBox","Button"].contains($0.component)}) else { throw GeneratedUIError.invalid }
        }
        guard deleted || nodes["root"] != nil else { throw GeneratedUIError.invalid }
        return Self(catalogID:create.catalogId,surfaceID:create.surfaceId,messages:messages,deleted:deleted)
    }
    private static func validateComponent(_ c: RawComponent) throws {
        switch c.component {
        case "Text": _ = try c.typedProperties(TextProperties.self)
        case "Column": _ = try c.typedProperties(ColumnProperties.self); _ = try children(c)
        case "Row": _ = try c.typedProperties(RowProperties.self); _ = try children(c)
        case "Card": _ = try c.typedProperties(CardProperties.self)
        case "Divider": _ = try c.typedProperties(DividerProperties.self)
        case "TextField":
            let props = try c.typedProperties(TextFieldProperties.self)
            guard props.validationRegexp == nil, props.checks == nil else { throw GeneratedUIError.unsupported }
        case "CheckBox": _ = try c.typedProperties(CheckBoxProperties.self)
        case "ChoicePicker":
            let p = try c.typedProperties(ChoicePickerProperties.self)
            guard p.options.count <= 32, Set(p.options.map(\.value)).count == p.options.count else { throw GeneratedUIError.invalid }
        case "Slider":
            let p = try c.typedProperties(SliderProperties.self)
            guard p.max.isFinite, (p.min ?? 0).isFinite, p.max > (p.min ?? 0), abs(p.max) < 1_000_000, abs(p.min ?? 0) < 1_000_000 else { throw GeneratedUIError.invalid }
        case "Button":
            let p = try c.typedProperties(ButtonProperties.self)
            guard case .event(let name,_) = p.action, validID(name) else { throw GeneratedUIError.unsupported }
        case "Forecast","ImageCarousel","Chart": try validateRich(c)
        case "AudioPlayer","Video": try decodeRich(MediaContent.self,component:c).validate()
        case "Dashboard": _ = try children(c)
        case "Metric","DataTable","Timeline","Checklist": try validateExpanded(c)
        default: throw GeneratedUIError.unsupported
        }
    }
    private static func children(_ c: RawComponent) throws -> [String] {
        switch c.component {
        case "Row","Column","Dashboard","Checklist":
            guard case .array(let items) = c.properties["children"] else { throw GeneratedUIError.unsupported }
            return try items.map { item in
                guard let id = item.stringValue, validID(id) else { throw GeneratedUIError.invalid }
                return id
            }
        case "Card","Button":
            guard let id = c.properties["child"]?.stringValue, validID(id) else { throw GeneratedUIError.invalid }
            return [id]
        default: return []
        }
    }
    private static func walk(_ key: String,nodes:[String:RawComponent],ancestors:Set<String>,depth:Int,count:inout Int,allowMissing:Bool = false) throws {
        count += 1
        guard depth <= 12, count <= 128, !ancestors.contains(key) else { throw GeneratedUIError.invalid }
        guard let node = nodes[key] else {
            if allowMissing { return }
            throw GeneratedUIError.invalid
        }
        for child in try children(node) { try walk(child,nodes:nodes,ancestors:ancestors.union([key]),depth:depth + 1,count:&count,allowMissing:allowMissing) }
    }
    static func validID(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 128 && value.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.union(CharacterSet(charactersIn:"_.:-")).contains($0) }
    }
    static func validatePath(_ value: String) throws {
        let segments = value.split(separator:"/",omittingEmptySubsequences:false).dropFirst()
        guard value.hasPrefix("/"), value.utf8.count <= 512, segments.count <= 12 else { throw GeneratedUIError.invalid }
        for segment in segments {
            // SDK array writes expand to the index. Reject huge or negative indices.
            if let number = Int(segment) { guard (0..<128).contains(number) else { throw GeneratedUIError.invalid } }
            else if !segment.isEmpty && segment.allSatisfy({ $0.isNumber || $0 == "-" }) { throw GeneratedUIError.invalid }
        }
    }
    private static func bounded(_ value: Any,depth:Int,budget:inout Int) throws {
        budget -= 1
        guard depth <= 20, budget >= 0 else { throw GeneratedUIError.tooLarge }
        if let dict = value as? [String:Any] {
            for (key,item) in dict {
                guard !["call","checks","validationRegexp"].contains(key) else { throw GeneratedUIError.unsupported }
                if key == "path", let path = item as? String { try validatePath(path) }
                try bounded(item,depth:depth + 1,budget:&budget)
            }
        } else if let array = value as? [Any] {
            guard array.count <= 128 else { throw GeneratedUIError.tooLarge }
            for item in array { try bounded(item,depth:depth + 1,budget:&budget) }
        } else if let string = value as? String, string.utf8.count > 8192 { throw GeneratedUIError.tooLarge }
    }
}
