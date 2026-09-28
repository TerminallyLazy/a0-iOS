import SwiftUI
import A0Core

/// Read-only server accounting. Missing categories remain unavailable, never estimated.
struct ContextUsageButton:View {
    let model:SpikeModel
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo:.caption2) private var ringSize:CGFloat = 32
    @State private var usage:ContextUsage?
    @State private var displayedIdentity:String?
    @State private var presented = false
    @State private var loading = false
    @State private var unavailable = false
    private var requestKey:String { "\(model.connectionGeneration)-\(model.chat?.selectedContext ?? "")-\(model.canSubmit)-\(model.state.logVersion)" }
    var body:some View {
        Button { presented = true } label: {
            ZStack {
                Circle().stroke(Color.a0Supporting.opacity(0.3),lineWidth:2)
                if let fraction = usage?.meterFraction {
                    Circle().trim(from:0,to:fraction).stroke(Color.primary,style:StrokeStyle(lineWidth:2,lineCap:.round)).rotationEffect(.degrees(-90))
                }
                if let fraction = usage?.usedFraction { Text(fraction,format:.percent.precision(.fractionLength(0))).font(.caption2.weight(.medium)) }
                else { Image(systemName:"chart.pie").font(.caption) }
            }.frame(width:ringSize,height:ringSize).frame(minWidth:44,minHeight:44)
        }
        .accessibilityLabel("Context window").accessibilityValue(usage?.usedFraction.map { $0.formatted(.percent.precision(.fractionLength(1))) + " used" } ?? "Usage unavailable")
        .accessibilityIdentifier("contextUsage")
        .popover(isPresented:$presented,arrowEdge:.bottom) {
            ScrollView {
                VStack(alignment:.leading,spacing:14) {
                    HStack { Text("Context window").font(.headline); Spacer(); Button("Close",systemImage:"xmark") { presented = false }.labelStyle(.iconOnly).frame(width:44,height:44) }
                    if let usage {
                        ViewThatFits(in:.horizontal) {
                            HStack { totals(usage); Spacer(); used(usage) }
                            VStack(alignment:.leading,spacing:6) { totals(usage); used(usage) }
                        }.font(.caption).monospacedDigit()
                        if let fraction = usage.meterFraction { ProgressView(value:fraction).tint(.primary) }
                        if usage.hasBreakdown {
                            ForEach(usage.buckets) { bucket in
                                row(bucket.label,tokens:bucket.tokens,fraction:bucket.fraction)
                            }
                        } else { Text("This server has not reported a category breakdown yet.").font(.footnote).foregroundStyle(Color.a0Supporting) }
                        if let remaining = usage.remainingTokens { row("Free space",tokens:remaining,fraction:usage.remainingFraction) }
                        if usage.providerUsage.hasData {
                            Divider()
                            if let fraction = usage.providerUsage.cacheHitFraction { HStack { Text("Cache hit"); Spacer(); Text(fraction,format:.percent.precision(.fractionLength(0))).fixedSize() } }
                            if usage.providerUsage.inputTokens != nil || usage.providerUsage.outputTokens != nil {
                                HStack { Text("Tokens In/Out"); Spacer(); Text("\(usage.providerUsage.inputTokens.map(compact) ?? "—") → \(usage.providerUsage.outputTokens.map(compact) ?? "—")").fixedSize().font(.caption) }
                            }
                        }
                    } else {
                        if loading { ProgressView("Reading context…") }
                        else { Text("Context usage is not available from this server yet.").foregroundStyle(Color.a0Supporting) }
                    }
                    if unavailable,usage != nil { Text("Could not refresh. Showing the last server report.").font(.caption).foregroundStyle(Color.a0Supporting) }
                }.font(.subheadline).padding(16)
            }.accessibilityIdentifier("contextUsageScroll").frame(idealWidth:typeSize.isAccessibilitySize ? 420 : 320,maxWidth:typeSize.isAccessibilitySize ? 420 : 320).frame(maxHeight:560).fixedSize(horizontal:false,vertical:true)
                .presentationCompactAdaptation(.popover)
        }
        .task(id:requestKey) { await refresh() }
    }
    private func compact(_ value:Int) -> String { value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1))) }
    private func totals(_ value:ContextUsage) -> some View {
        ViewThatFits(in:.horizontal) {
            Text("\(compact(value.tokens)) / \(value.contextWindow > 0 ? compact(value.contextWindow) : "—") tokens").fixedSize()
            VStack(alignment:.leading,spacing:2) {
                Text("\(compact(value.tokens)) / \(value.contextWindow > 0 ? compact(value.contextWindow) : "—")").fixedSize()
                Text("tokens")
            }
        }
    }
    @ViewBuilder private func used(_ value:ContextUsage) -> some View {
        if let fraction = value.usedFraction { (Text(fraction,format:.percent.precision(.fractionLength(1))) + Text(" used")).fixedSize(horizontal:true,vertical:false) }
    }
    @ViewBuilder private func row(_ label:String,tokens:Int,fraction:Double?) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment:.leading,spacing:4) {
                Text(label).fixedSize(horizontal:false,vertical:true)
                HStack {
                    Text(compact(tokens)).foregroundStyle(Color.a0Supporting).fixedSize()
                    Spacer()
                    if let fraction { Text(fraction,format:.percent.precision(.fractionLength(1))).fixedSize() }
                }.font(.caption).monospacedDigit()
            }
        } else {
            HStack {
                Text(label); Spacer(minLength:8)
                Text(compact(tokens)).foregroundStyle(Color.a0Supporting).fixedSize()
                if let fraction { Text(fraction,format:.percent.precision(.fractionLength(1))).fixedSize().frame(minWidth:46,alignment:.trailing) }
            }.monospacedDigit()
        }
    }
    private func refresh() async {
        let identity = "\(model.connectionGeneration)-\(model.chat?.selectedContext ?? "")"
        if displayedIdentity != identity { usage = nil; unavailable = false; displayedIdentity = identity }
        guard model.canSubmit,let context = model.chat?.selectedContext,let client = model.controlClient else { usage = nil; return }
        let generation = model.connectionGeneration
        loading = true
        defer { loading = false }
        do {
            try await Task.sleep(for:.milliseconds(500))
            let value = try await client.contextUsage(context:context)
            guard !Task.isCancelled,generation == model.connectionGeneration,context == model.chat?.selectedContext else { return }
            usage = value; unavailable = false
        } catch {
            guard !Task.isCancelled,generation == model.connectionGeneration,context == model.chat?.selectedContext else { return }
            unavailable = true
        }
    }
}
