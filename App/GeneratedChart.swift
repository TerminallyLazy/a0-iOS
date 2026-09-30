import SwiftUI
import Charts
import A0GenerativeUI

struct GeneratedChart:View {
    @Environment(\.a0Theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    let value:A0GenerativeUI.ChartContent
    private var colors:[Color] { [theme.tint,.orange,.teal,.purple,.pink,.cyan,.yellow,.indigo] }
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            Text(value.title).font(.headline)
            Text(value.yLabel).font(.caption).foregroundStyle(theme.muted)
            if let x = value.xLabel, !value.isCircular { Text("Horizontal axis: " + (value.kind == "horizontalBar" ? value.yLabel : x)).font(.caption).foregroundStyle(theme.muted) }
            if value.kind == "bubble" { Text("Bubble area: " + (value.sizeLabel ?? "Size")).font(.caption).foregroundStyle(theme.muted) }
            plot
                .chartXAxis { AxisMarks { AxisGridLine().foregroundStyle(theme.muted.opacity(0.25)); AxisValueLabel().foregroundStyle(theme.muted) } }
                .chartYAxis { AxisMarks { AxisGridLine().foregroundStyle(theme.muted.opacity(0.25)); AxisValueLabel().foregroundStyle(theme.muted) } }
                .frame(height:typeSize.isAccessibilitySize ? 360 : 250)
                .accessibilityLabel(value.title)
            if value.isCircular || value.series.count > 1 {
                // A wrapping, text-sized legend avoids clipped SDK legend rows.
                ViewThatFits(in:.horizontal) {
                    legend(horizontal:true)
                    legend(horizontal:false)
                }
            }
            DisclosureGroup("View values") {
                ForEach(Array(value.points.enumerated()),id:\.offset) { index,point in
                    VStack(alignment:.leading,spacing:4) {
                        Text(point.name).fontWeight(.medium)
                        Text(point.detail).foregroundStyle(theme.muted).monospacedDigit()
                    }.frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,4).accessibilityElement(children:.combine).accessibilityIdentifier("chart-value-\(index)")
                }
            }.font(.subheadline)
            if let url = value.sourceURL { sourceLink(url) }
        }.padding(.vertical,12)
    }
    @ViewBuilder private var plot:some View {
        if value.kind == "heatmap" {
            Chart(Array(value.points.enumerated()),id:\.offset) { _,p in
                RectangleMark(x:.value(value.xLabel ?? "Column",p.label),y:.value("Row",p.row ?? ""))
                    .foregroundStyle(by:.value(value.yLabel,p.value))
                    .accessibilityLabel(p.name).accessibilityValue(p.value.formatted())
            }.chartForegroundStyleScale(range:Gradient(colors:[theme.tint.opacity(0.3),theme.tint]))
        } else {
            Chart(Array(value.points.enumerated()),id:\.offset) { _,p in
                marks(p).accessibilityLabel(p.name).accessibilityValue(p.detail)
            }
            .chartForegroundStyleScale(domain:value.isCircular ? value.categories : value.series,range:colors)
            .chartLegend(.hidden)
            .chartXScale(domain:.automatic(includesZero:value.kind == "horizontalBar"))
            .chartYScale(domain:.automatic(includesZero:!["scatter","bubble","range"].contains(value.kind)))
        }
    }
    @ChartContentBuilder private func marks(_ p:A0GenerativeUI.ChartContent.Point)->some Charts.ChartContent {
        let series = p.series ?? value.title
        switch value.kind {
        case "pie","donut":
            SectorMark(angle:.value(value.yLabel,p.value),innerRadius:.ratio(value.kind == "donut" ? 0.58:0),angularInset:1)
                .foregroundStyle(by:.value("Category",p.label))
        case "scatter","bubble":
            PointMark(x:.value(value.xLabel ?? "X",p.x ?? 0),y:.value(value.yLabel,p.value))
                .foregroundStyle(by:.value("Series",series))
                .symbol(by:.value("Series",series))
                .symbolSize(value.kind == "bubble" ? 500 * (p.size ?? 1) / (value.points.compactMap(\.size).max() ?? 1) : 45)
        case "horizontalBar":
            BarMark(x:.value(value.yLabel,p.value),y:.value("Category",p.label))
                .foregroundStyle(by:.value("Series",series))
        case "groupedBar":
            BarMark(x:.value("Category",p.label),y:.value(value.yLabel,p.value))
                .foregroundStyle(by:.value("Series",series)).position(by:.value("Series",series))
        case "bar","stackedBar":
            BarMark(x:.value("Category",p.label),y:.value(value.yLabel,p.value))
                .foregroundStyle(by:.value("Series",series))
        case "histogram":
            BarMark(xStart:.value(value.xLabel ?? "Lower",p.lower ?? 0),xEnd:.value(value.xLabel ?? "Upper",p.upper ?? 0),y:.value(value.yLabel,p.value))
                .foregroundStyle(by:.value("Series",series))
        case "range":
            RuleMark(x:.value("Category",p.label),yStart:.value("Lower",p.lower ?? 0),yEnd:.value("Upper",p.upper ?? 0))
                .foregroundStyle(by:.value("Series",series)).lineStyle(StrokeStyle(lineWidth:4))
            PointMark(x:.value("Category",p.label),y:.value(value.yLabel,p.value))
                .foregroundStyle(by:.value("Series",series)).symbol(.diamond)
        case "area","stackedArea":
            AreaMark(x:.value("Category",p.label),y:.value(value.yLabel,p.value),series:.value("Series",series),stacking:value.kind == "stackedArea" ? .standard:.unstacked)
                .foregroundStyle(by:.value("Series",series)).opacity(0.6)
        default:
            LineMark(x:.value("Category",p.label),y:.value(value.yLabel,p.value),series:.value("Series",series))
                .foregroundStyle(by:.value("Series",series)).symbol(by:.value("Series",series))
                .lineStyle(by:.value("Series",series))
        }
    }
    private func legend(horizontal:Bool)->some View {
        let layout = horizontal ? AnyLayout(HStackLayout(spacing:12)) : AnyLayout(VStackLayout(alignment:.leading,spacing:6))
        return layout {
            ForEach(Array((value.isCircular ? value.categories : value.series).enumerated()),id:\.offset) { index,label in
                Label { Text(label) } icon: { Circle().fill(colors[index % colors.count]).frame(width:8,height:8) }
            }
        }.font(.caption)
    }
}
