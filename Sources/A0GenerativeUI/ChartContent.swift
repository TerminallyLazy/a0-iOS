import Foundation

/// Display-ready observations; never generates measurements or computes missing bins.
public struct ChartContent: Decodable, Sendable {
    public struct Point: Decodable, Sendable {
        public let label:String
        public let value:Double
        public let series:String?
        public let x:Double?
        public let size:Double?
        public let lower:Double?
        public let upper:Double?
        public let row:String?
        public var name:String { label + (series.map { " · " + $0 } ?? "") + (row.map { " · " + $0 } ?? "") }
        public var detail:String {
            var fields = [value.formatted()]
            if let x { fields.append("x: " + x.formatted()) }
            if let lower, let upper { fields.append("Range: \(lower.formatted())–\(upper.formatted())") }
            if let size { fields.append("Size: " + size.formatted()) }
            return fields.joined(separator:"; ")
        }
    }
    public let title:String
    public let kind:String
    public let yLabel:String
    public let xLabel:String?
    public let sizeLabel:String?
    public let points:[Point]
    public let sourceURL:String?
    public static let kinds:Set<String> = ["line","bar","area","horizontalBar","groupedBar","stackedBar","stackedArea","pie","donut","scatter","bubble","histogram","range","heatmap"]
    public var series:[String] { points.reduce(into:[]) { if !$0.contains($1.series ?? title) { $0.append($1.series ?? title) } } }
    public var categories:[String] { points.reduce(into:[]) { if !$0.contains($1.label) { $0.append($1.label) } } }
    public var isCircular:Bool { ["pie","donut"].contains(kind) }
    public var isNumericX:Bool { ["scatter","bubble","histogram"].contains(kind) }
    func validate() throws {
        func text(_ s:String)->Bool { !s.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && s.utf8.count <= 160 }
        func number(_ d:Double)->Bool { d.isFinite && abs(d) < 1e12 }
        guard Self.kinds.contains(kind), text(title), text(yLabel), xLabel.map(text) ?? true, sizeLabel.map(text) ?? true,
              (1...128).contains(points.count), series.count <= 8,
              sourceURL.map({RichImagePolicy.url($0) != nil}) ?? true,
              points.allSatisfy({ text($0.label) && number($0.value) && ($0.series.map(text) ?? true) && ($0.row.map(text) ?? true)
                  && [$0.x,$0.size,$0.lower,$0.upper].compactMap({$0}).allSatisfy(number) }) else { throw GeneratedUIError.invalid }
        if !isNumericX { guard categories.count <= 32 else { throw GeneratedUIError.invalid } }
        var seen:Set<[String]> = []
        for p in points {
            if !isNumericX {
                let key = kind == "heatmap" ? [p.label,p.row ?? ""] : [p.label,p.series ?? ""]
                guard seen.insert(key).inserted else { throw GeneratedUIError.invalid }
            }
            switch kind {
            case "pie","donut":
                guard points.count <= 7, p.value > 0, p.series == nil else { throw GeneratedUIError.invalid }
            case "scatter","bubble":
                guard p.x != nil, xLabel != nil else { throw GeneratedUIError.invalid }
                if kind == "bubble" { guard let size = p.size, size > 0 else { throw GeneratedUIError.invalid } }
            case "range","histogram":
                guard let lower = p.lower, let upper = p.upper, lower < upper else { throw GeneratedUIError.invalid }
                if kind == "range" { guard (lower...upper).contains(p.value) else { throw GeneratedUIError.invalid } }
                else { guard p.value >= 0, p.series == nil, xLabel != nil else { throw GeneratedUIError.invalid } }
            case "heatmap": guard p.row != nil, p.series == nil else { throw GeneratedUIError.invalid }
            case "stackedArea": guard p.value >= 0 else { throw GeneratedUIError.invalid }
            default: break
            }
        }
        if kind == "histogram" {
            for pair in zip(points,points.dropFirst()) {
                guard pair.0.upper! <= pair.1.lower! else { throw GeneratedUIError.invalid }
            }
        }
    }
}
