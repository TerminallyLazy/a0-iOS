import SwiftUI
import Charts
import A2UISwiftUI
import A2UISwiftCore
import A0GenerativeUI

struct GeneratedCatalog: CustomComponentCatalog {
    @ViewBuilder func build(typeName:String,node:ComponentNode,surface:SurfaceModel) -> some View {
        switch typeName {
        case "A0TextField": NativeGeneratedInput(node:node,surface:surface)
        case "Forecast":
            if let value = decode(ForecastContent.self,node) { ForecastView(value:value) }
        case "ImageCarousel":
            if let value = decode(CarouselContent.self,node) { GeneratedCarousel(value:value) }
        case "Chart":
            if let value = decode(A0GenerativeUI.ChartContent.self,node) { GeneratedChart(value:value) }
        case "Dashboard": GeneratedDashboard(node:node,surface:surface)
        default: EmptyView()
        }
    }
    private func decode<T:Decodable>(_ type:T.Type,_ node:ComponentNode) -> T? {
        try? JSONDecoder().decode(type,from:JSONEncoder().encode(node.instance.properties))
    }
}
private struct NativeGeneratedInput: View {
    @Environment(\.a0Theme) private var theme
    let node:ComponentNode
    let surface:SurfaceModel
    var body: some View {
        if let p = try? node.typedProperties(TextFieldProperties.self) {
            let dc = DataContext(surface:surface,path:node.dataContextPath)
            let label = dc.resolve(p.label).isEmpty ? "Response" : dc.resolve(p.label)
            let binding = dc.stringBinding(for:p.value)
            VStack(alignment:.leading,spacing:6) {
                Text(label).font(.subheadline.weight(.medium)).foregroundStyle(theme.text)
                if p.variant == .obscured {
                    SecureField(label,text:binding).textFieldStyle(.roundedBorder).accessibilityLabel(label)
                } else {
                    TextField(label,text:binding,prompt:Text("Enter a response").foregroundStyle(theme.muted),axis:p.variant == .longText ? .vertical : .horizontal)
                        .lineLimit(1...6).keyboardType(p.variant == .number ? .decimalPad : .default)
                        .textFieldStyle(.plain).padding(12).frame(minHeight:44)
                        .background(theme.canvas,in:RoundedRectangle(cornerRadius:10)).accessibilityLabel(label)
                }
            }.padding(8)
        }
    }
}
private struct ForecastView: View {
    @Environment(\.a0Theme) private var theme
    let value:ForecastContent
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            VStack(alignment:.leading,spacing:4) {
                Text(value.location).font(.headline)
                Text(value.updatedAt).font(.caption).foregroundStyle(theme.muted)
            }
            HStack(alignment:.center,spacing:18) {
                Image(systemName:symbol(value.icon)).font(.largeTitle).symbolRenderingMode(.hierarchical).accessibilityHidden(true)
                VStack(alignment:.leading,spacing:4) {
                    Text("\(value.temperature,format:.number.precision(.fractionLength(0)))°\(value.unit)").font(.largeTitle.weight(.medium)).monospacedDigit()
                    Text(value.condition).font(.subheadline)
                }
            }.accessibilityElement(children:.combine)
            if !value.days.isEmpty {
                ScrollView(.horizontal) {
                    HStack(alignment:.top,spacing:22) {
                        ForEach(Array(value.days.enumerated()),id:\.offset) { _,day in
                            VStack(spacing:8) {
                                Text(day.label).font(.subheadline.weight(.medium))
                                Image(systemName:symbol(day.icon)).font(.title3).accessibilityHidden(true)
                                Text("\(day.high,format:.number.precision(.fractionLength(0)))° / \(day.low,format:.number.precision(.fractionLength(0)))°").font(.subheadline).monospacedDigit()
                                Text(day.condition).font(.caption).foregroundStyle(theme.muted)
                            }.frame(minWidth:80).accessibilityElement(children:.combine)
                        }
                    }.padding(.vertical,4)
                }
            }
            sourceLink(value.sourceURL)
        }.padding(.vertical,12)
    }
    private func symbol(_ icon:String) -> String {
        ["sun":"sun.max","cloud":"cloud.sun","rain":"cloud.rain","snow":"cloud.snow","storm":"cloud.bolt.rain","wind":"wind","fog":"cloud.fog"][icon] ?? "cloud"
    }
}
private struct GeneratedChart: View {
    @Environment(\.a0Theme) private var theme
    let value:A0GenerativeUI.ChartContent
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            Text(value.title).font(.headline)
            Text(value.yLabel).font(.caption).foregroundStyle(theme.muted)
            Chart(Array(value.points.enumerated()),id:\.offset) { _,point in
                if value.kind == "bar" {
                    BarMark(x:.value("Label",point.label),y:.value(value.yLabel,point.value))
                        .foregroundStyle(by:.value("Series",point.series ?? value.title))
                } else if value.kind == "area" {
                    AreaMark(x:.value("Label",point.label),y:.value(value.yLabel,point.value),series:.value("Series",point.series ?? value.title))
                        .foregroundStyle(by:.value("Series",point.series ?? value.title)).opacity(0.25)
                    LineMark(x:.value("Label",point.label),y:.value(value.yLabel,point.value),series:.value("Series",point.series ?? value.title))
                        .foregroundStyle(by:.value("Series",point.series ?? value.title))
                } else {
                    LineMark(x:.value("Label",point.label),y:.value(value.yLabel,point.value),series:.value("Series",point.series ?? value.title))
                        .foregroundStyle(by:.value("Series",point.series ?? value.title)).symbol(.circle)
                }
            }.chartLegend(value.points.contains(where:{$0.series != nil}) ? .visible : .hidden)
                .frame(height:220).accessibilityLabel(value.title)
            DisclosureGroup("View values") {
                ForEach(Array(value.points.enumerated()),id:\.offset) { _,point in
                    LabeledContent(point.label + (point.series.map { " · " + $0 } ?? ""),value:point.value.formatted())
                }
            }.font(.subheadline)
            if let url = value.sourceURL { sourceLink(url) }
        }.padding(.vertical,12)
    }
}
private struct GeneratedCarousel: View {
    @Environment(\.a0Theme) private var theme
    let value:CarouselContent
    @State private var selection = 0
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack(alignment:.firstTextBaseline) {
                Text(value.title).font(.headline)
                Spacer()
                Text("\(selection + 1) of \(value.images.count)").font(.caption).foregroundStyle(theme.muted)
            }
            TabView(selection:$selection) {
                ForEach(Array(value.images.enumerated()),id:\.offset) { index,item in
                    RemoteGeneratedImage(url:item.url,title:item.title).tag(index)
                }
            }.tabViewStyle(.page(indexDisplayMode:.never)).frame(height:240).clipShape(RoundedRectangle(cornerRadius:12))
            if value.images.indices.contains(selection) {
                Text(value.images[selection].title).font(.subheadline)
                HStack {
                    sourceLink(value.images[selection].sourceURL)
                    Spacer()
                    Button("Previous image",systemImage:"chevron.left") { selection = max(0,selection - 1) }
                        .labelStyle(.iconOnly).frame(width:44,height:44).disabled(selection == 0)
                    Button("Next image",systemImage:"chevron.right") { selection = min(value.images.count - 1,selection + 1) }
                        .labelStyle(.iconOnly).frame(width:44,height:44).disabled(selection == value.images.count - 1)
                }
            }
        }.padding(.vertical,12)
    }
}
private struct GeneratedDashboard: View {
    @Environment(\.a0Theme) private var theme
    let node:ComponentNode
    let surface:SurfaceModel
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        LazyVGrid(columns:[GridItem(typeSize.isAccessibilitySize ? .flexible() : .adaptive(minimum:280),spacing:20)],alignment:.leading,spacing:20) {
            ForEach(node.children) { child in A2UIChildView(node:child,surface:surface).frame(maxWidth:.infinity,alignment:.leading) }
        }
    }
}
@MainActor @ViewBuilder private func sourceLink(_ string:String) -> some View {
    if let url = URL(string:string) {
        Link(destination:url) { Label("Source · " + (url.host ?? "Website"),systemImage:"arrow.up.right.square").font(.caption).frame(minHeight:44) }.accessibilityIdentifier("generatedSource-" + (url.host ?? "website"))
    }
}
