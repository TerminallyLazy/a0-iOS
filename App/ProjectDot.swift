import SwiftUI

/// Matches the server's project color; a ring keeps pale colors visible in both appearances.
struct ProjectDot: View {
    let color: String
    var size: CGFloat = 10
    var body: some View {
        Circle().fill(color.isEmpty ? Color.clear : Self.color(color)).frame(width:size,height:size)
            .overlay { Circle().strokeBorder(Color.primary.opacity(color.isEmpty ? 0.5 : 0.28),lineWidth:0.75) }
            .accessibilityHidden(true)
    }
    static func color(_ value:String) -> Color {
        let hex = value.hasPrefix("#") ? String(value.dropFirst()) : value
        guard [6,8].contains(hex.count),let number = UInt64(hex,radix:16) else { return Color.a0Supporting }
        let rgb = hex.count == 8 ? number >> 8 : number
        return Color(red:Double((rgb >> 16) & 255)/255,green:Double((rgb >> 8) & 255)/255,blue:Double(rgb & 255)/255,opacity:hex.count == 8 ? Double(number & 255)/255 : 1)
    }
}
