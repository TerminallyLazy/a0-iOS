import SwiftUI
import A0Core

struct MarkdownView: View {
    @Environment(\.a0Theme) private var theme
    let source: String
    @State private var blocks: [MarkdownBlock] = []
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            ForEach(Array(blocks.enumerated()),id:\.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth:.infinity,alignment:.leading)
        .textSelection(.enabled)
        .task(id:source) {
            let value = source
            let parsed = await Task.detached(priority:.userInitiated) { MarkdownDocument.parse(value) }.value
            guard !Task.isCancelled else { return }; blocks = parsed
        }
    }
    @ViewBuilder private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level,let text):
            InlineMarkdown(source:text).font(level == 1 ? .title2 : level == 2 ? .title3 : .headline).fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
        case .paragraph(let text): InlineMarkdown(source:text)
        case .listItem(let marker,let text):
            HStack(alignment:.firstTextBaseline,spacing:10) { Text(marker).foregroundStyle(theme.muted); InlineMarkdown(source:text) }
        case .quote(let text):
            HStack(alignment:.top,spacing:10) { Image(systemName:"quote.opening").foregroundStyle(theme.muted); InlineMarkdown(source:text).italic() }
        case .divider: Divider()
        case .code(let language,let code): CodeBlock(language:language,code:code)
        case .table(let rows):
            ScrollView(.horizontal) {
                Grid(alignment:.leading,horizontalSpacing:20,verticalSpacing:10) {
                    ForEach(Array(rows.enumerated()),id:\.offset) { index,row in
                        GridRow { ForEach(Array(row.enumerated()),id:\.offset) { _,cell in
                            InlineMarkdown(source:cell).fontWeight(index == 0 ? .semibold : .regular)
                        } }
                        if index == 0 { Divider() }
                    }
                }.padding(12)
            }.background(theme.panel,in:RoundedRectangle(cornerRadius:12))
        }
    }
}

struct InlineMarkdown: View {
    @Environment(\.a0Theme) private var theme
    let source: String
    @State private var text: AttributedString?
    var body: some View {
        Text(text ?? AttributedString(source)).fixedSize(horizontal:false,vertical:true)
            .task(id:source) {
                let value = source
                let parsed = await Task.detached(priority:.userInitiated) {
                    // Images stay descriptive text. No remote fetch or HTML execution.
                    let safe = value.replacingOccurrences(of:"!\\[([^\\]]*)\\]\\([^)]*\\)",with:"$1 (image)",options:.regularExpression)
                    return (try? AttributedString(markdown:safe,options:.init(interpretedSyntax:.inlineOnlyPreservingWhitespace))) ?? AttributedString(safe)
                }.value
                guard !Task.isCancelled else { return }; text = parsed
            }
    }
}

private struct CodeBlock: View {
    @Environment(\.a0Theme) private var theme
    let language: String
    let code: String
    @State private var copied = false
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {
                Text(language.isEmpty ? "Code" : language).font(.caption).foregroundStyle(theme.muted)
                Spacer()
                Button {
                    UIPasteboard.general.string = code; copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy code",systemImage:copied ? "checkmark" : "doc.on.doc")
                        .font(.caption).frame(minHeight:44)
                }
            }
            ScrollView(.horizontal) { Text(verbatim:code).font(.system(.callout,design:.monospaced)).textSelection(.enabled) }
        }.padding(12).background(theme.panel,in:RoundedRectangle(cornerRadius:12))
    }
}
