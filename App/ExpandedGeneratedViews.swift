import SwiftUI
import A2UISwiftUI
import A2UISwiftCore
import A0GenerativeUI

struct GeneratedMetric: View {
    @Environment(\.a0Theme) private var theme
    let value:MetricContent
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            Text(value.title).font(.headline)
            Text(value.value).font(.largeTitle.weight(.semibold)).monospacedDigit().fixedSize(horizontal:false,vertical:true)
            if let unit = value.unit { Text(unit).font(.subheadline).foregroundStyle(theme.muted) }
            if let change = value.change {
                Label(change,systemImage:value.trend == "up" ? "arrow.up.right" : value.trend == "down" ? "arrow.down.right" : "minus")
                    .font(.subheadline).foregroundStyle(theme.muted)
            }
            if let url = value.sourceURL { sourceLink(url) }
        }.frame(maxWidth:.infinity,alignment:.leading).padding(16).background(theme.canvas,in:RoundedRectangle(cornerRadius:14))
    }
}
struct GeneratedDataTable: View {
    @Environment(\.a0Theme) private var theme
    @Environment(\.dynamicTypeSize) private var size
    @Environment(\.horizontalSizeClass) private var widthClass
    let value:DataTableContent
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            Text(value.title).font(.headline)
            if size.isAccessibilitySize || (widthClass == .compact && value.columns.count > 2) {
                ForEach(Array(value.rows.enumerated()),id:\.offset) { index,row in
                    VStack(alignment:.leading,spacing:8) {
                        Text("Row \(index+1)").font(.caption).foregroundStyle(theme.muted)
                        ForEach(Array(value.columns.enumerated()),id:\.offset) { column,title in
                            VStack(alignment:.leading,spacing:4) { Text(title).font(.subheadline.weight(.semibold)); Text(row[column].isEmpty ? "—" : row[column]) }
                        }
                    }.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(theme.canvas,in:RoundedRectangle(cornerRadius:10))
                }
            } else {
                Grid(alignment:.leading,horizontalSpacing:12,verticalSpacing:12) {
                    GridRow(alignment:.top) {
                        ForEach(value.columns,id:\.self) { title in
                            Text(title).font(.subheadline.weight(.semibold))
                                .frame(maxWidth:.infinity,alignment:.leading)
                        }
                    }
                    Divider().gridCellUnsizedAxes(.horizontal)
                    ForEach(Array(value.rows.enumerated()),id:\.offset) { _,row in
                        GridRow(alignment:.top) {
                            ForEach(Array(row.enumerated()),id:\.offset) { index,cell in
                                Text(cell.isEmpty ? "—" : cell).font(.subheadline)
                                    .fixedSize(horizontal:false,vertical:true)
                                    .frame(maxWidth:.infinity,alignment:.leading)
                                    .accessibilityLabel(value.columns[index] + ": " + (cell.isEmpty ? "Empty" : cell))
                            }
                        }
                        Divider().gridCellUnsizedAxes(.horizontal)
                    }
                }.padding(12).background(theme.canvas,in:RoundedRectangle(cornerRadius:10))
            }
            if let url = value.sourceURL { sourceLink(url) }
        }.padding(.vertical,8)
    }
}
struct GeneratedTimeline: View {
    @Environment(\.a0Theme) private var theme
    let value:TimelineContent
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            Text(value.title).font(.headline)
            ForEach(value.items,id:\.id) { item in
                HStack(alignment:.top,spacing:12) {
                    Image(systemName:item.state == "complete" ? "checkmark.circle" : item.state == "current" ? "circle.inset.filled" : "circle")
                        .foregroundStyle(theme.tint).accessibilityHidden(true)
                    VStack(alignment:.leading,spacing:6) {
                        Text(item.title).font(.subheadline.weight(.semibold))
                        if let time = item.time { Text(time).font(.caption).foregroundStyle(theme.muted) }
                        if let detail = item.detail { Text(detail).font(.subheadline) }
                        if let state = item.state { Text(state.capitalized).font(.caption).foregroundStyle(theme.muted) }
                    }.frame(maxWidth:.infinity,alignment:.leading)
                }.accessibilityElement(children:.combine)
            }
            if let url = value.sourceURL { sourceLink(url) }
        }.padding(.vertical,8)
    }
}
struct GeneratedChecklist: View {
    let node:ComponentNode
    let surface:SurfaceModel
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            Text(node.instance.properties["title"]?.stringValue ?? "Checklist").font(.headline)
            ForEach(node.children) { child in A2UIChildView(node:child,surface:surface).frame(maxWidth:.infinity,alignment:.leading) }
        }.padding(.vertical,8)
    }
}
