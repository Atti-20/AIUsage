import SwiftUI

#if os(macOS)
import AppKit

private func dynamicColor(light: UInt32, dark: UInt32) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        return NSColor(hex: hex)
    })
}

private extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
#else
import UIKit

private func dynamicColor(light: UInt32, dark: UInt32) -> Color {
    Color(uiColor: UIColor { traits in
        UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
    })
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}
#endif

/// 图表配色。浅色 #CE6A2C/#2E7DE1、深色 #D4711F/#4C8BE8，
/// 已通过 CVD 区分度与表面对比度校验，固定分配、不轮换。
enum Palette {
    static let claude = dynamicColor(light: 0xCE6A2C, dark: 0xD4711F)
    static let codex = dynamicColor(light: 0x2E7DE1, dark: 0x4C8BE8)

    /// 模型占比等多分类场景的固定顺序色板（按成本降序分配）。
    static let categorical: [Color] = [
        claude,
        codex,
        dynamicColor(light: 0x7A5AF8, dark: 0x8E76F5),
        dynamicColor(light: 0x0F866C, dark: 0x2AA187),
        dynamicColor(light: 0x9A7B00, dark: 0xAD8F1F),
        dynamicColor(light: 0x8A8A85, dark: 0x9A9A94),
    ]

    static func color(for source: UsageSource) -> Color {
        source == .claude ? claude : codex
    }

    /// 限额环上的用量文字颜色：>90% 红、>70% 橙、否则常规。
    static func utilizationText(_ percent: Double) -> Color {
        if percent >= 90 { return .red }
        if percent >= 70 { return .orange }
        return .primary
    }
}
