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

/// 终端仪表盘设计系统。深色方案借鉴 codex-reset.com 的高对比数据界面，
/// 浅色方案保留相同语义，供小组件与系统强制浅色场景使用。
enum Palette {
    static let canvas = dynamicColor(light: 0xF4F7F5, dark: 0x0B0F0D)
    static let surface = dynamicColor(light: 0xFFFFFF, dark: 0x101713)
    static let surfaceRaised = dynamicColor(light: 0xEDF3EF, dark: 0x141E18)
    static let line = dynamicColor(light: 0xCBD8D0, dark: 0x26362C)
    static let ink = dynamicColor(light: 0x152019, dark: 0xE8EEE9)
    static let muted = dynamicColor(light: 0x5E6D64, dark: 0x87938B)
    static let signal = dynamicColor(light: 0x16813A, dark: 0x69F08A)
    static let warning = dynamicColor(light: 0x9A5A11, dark: 0xE5A965)
    static let danger = dynamicColor(light: 0xB63232, dark: 0xFF7777)

    static let claude = dynamicColor(light: 0xA95525, dark: 0xE08A52)
    static let codex = signal

    static let categorical: [Color] = [
        claude,
        codex,
        dynamicColor(light: 0x5E4DB2, dark: 0xA895FF),
        dynamicColor(light: 0x14796A, dark: 0x4BC6AE),
        dynamicColor(light: 0x8B6A09, dark: 0xE0BE54),
        muted,
    ]

    static func color(for source: UsageSource) -> Color {
        source == .claude ? claude : codex
    }

    static func utilizationText(_ percent: Double) -> Color {
        if percent >= 90 { return danger }
        if percent >= 70 { return warning }
        return signal
    }
}
