//
//  ContentView.swift
//  ColorInfo
//
//  Created by Qin Hangyu on 2025/3/11.
//

import Foundation
import AppKit
import SwiftUI


class ColorModel:ObservableObject {
    @Published var nsColor:NSColor = .white {
        didSet { updateAllValues() }
    }
    
    @Published var rgb = RGBValues()
    @Published var hsb = HSBValues()
    @Published var lab = LabValues()
        @Published var cmyk = CMYKValues()
        @Published var hexString = ""
        
        struct RGBValues {
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 1
        }
    
    struct HSBValues {
            var h: CGFloat = 0
            var s: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 1
        }
    
    struct LabValues {
            var l: CGFloat = 0
            var a: CGFloat = 0
            var b: CGFloat = 0
        }
    struct CMYKValues {
        var c: CGFloat = 0
        var m: CGFloat = 0
        var y: CGFloat = 0
        var k: CGFloat = 0
    }
    
    private func updateAllValues() {
        // macOS需要显式转换到RGB颜色空间
                guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else { return }
            
            // 更新RGB
        rgb = RGBValues(
                    r: rgbColor.redComponent * 255,
                    g: rgbColor.greenComponent * 255,
                    b: rgbColor.blueComponent * 255,
                    a: rgbColor.alphaComponent
                )
            
            // 更新HSB
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
                rgbColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
                hsb = HSBValues(h: h, s: s, b: b)
            
            // 更新Hex
        hexString = nsColor.toHexString()
            
            // 转换到CIELab和CMYK
            updateLabValues()
            updateCMYKValues()
        }
    
    private func updateLabValues() {
        // 确保使用RGB颜色空间
                guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else { return }
                
                // Step 1: 转换到线性RGB（sRGB逆伽马校正）
                let r = applyInverseGamma(rgbColor.redComponent)
                let g = applyInverseGamma(rgbColor.greenComponent)
                let b = applyInverseGamma(rgbColor.blueComponent)
                
                // Step 2: RGB转XYZ（使用D65白点的sRGB转换矩阵）
                let x = r * 0.4124564 + g * 0.3575761 + b * 0.1804375
                let y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750
                let z = r * 0.0193339 + g * 0.1191920 + b * 0.9503041
                
                // Step 3: XYZ转Lab（使用D65参考白点）
                let referenceX: CGFloat = 95.047
                let referenceY: CGFloat = 100.000
                let referenceZ: CGFloat = 108.883
                
                let xRatio = x / referenceX
                let yRatio = y / referenceY
                let zRatio = z / referenceZ
                
                func labTransform(_ t: CGFloat) -> CGFloat {
                    return t > 0.008856 ? pow(t, 1/3) : (7.787 * t) + (16/116)
                }
                
                let fx = labTransform(xRatio)
                let fy = labTransform(yRatio)
                let fz = labTransform(zRatio)
                
                let L = (116 * fy) - 16
                let a = 500 * (fx - fy)
                let labB = 200 * (fy - fz)
                
                lab = LabValues(
                    l: L.rounded(toPlaces: 2),
                    a: a.rounded(toPlaces: 2),
                    b: labB.rounded(toPlaces: 2)
                )
    }
    // 辅助方法：sRGB逆伽马校正
       private func applyInverseGamma(_ value: CGFloat) -> CGFloat {
           return value > 0.04045 ? pow((value + 0.055)/1.055, 2.4) : value/12.92
       }
    private func updateCMYKValues() {
            // 确保使用RGB颜色空间
            guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else { return }
            
            let r = rgbColor.redComponent
            let g = rgbColor.greenComponent
            let b = rgbColor.blueComponent
            
            let k = 1.0 - max(r, max(g, b))
            let denominator = 1.0 - k
            
            // 防止除以0（当k == 1时）
            let c = (denominator > 0.0001) ? (1.0 - r - k) / denominator : 0.0
            let m = (denominator > 0.0001) ? (1.0 - g - k) / denominator : 0.0
            let y = (denominator > 0.0001) ? (1.0 - b - k) / denominator : 0.0
            
            cmyk = CMYKValues(
                c: (c * 100).rounded(toPlaces: 2),
                m: (m * 100).rounded(toPlaces: 2),
                y: (y * 100).rounded(toPlaces: 2),
                k: (k * 100).rounded(toPlaces: 2)
            )
        }
        
    
}

// 更新ColorSlider组件以支持格式化
struct ColorSlider: View {
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let label: String
    let format: String
    var transform: (CGFloat) -> CGFloat = { $0 }
    
    var body: some View {
        HStack {
            Text(label).frame(width: 80, alignment: .leading)
            Slider(value: $value, in: range)
            Text(String(format: format, transform(value)))
                .frame(width: 60)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}
// NSColor扩展：处理Hex转换
extension NSColor {
    func toHexString() -> String {
            guard let rgbColor = self.usingColorSpace(.deviceRGB) else { return "" }
            
            let r = Int(round(rgbColor.redComponent * 0xFF))
            let g = Int(round(rgbColor.greenComponent * 0xFF))
            let b = Int(round(rgbColor.blueComponent * 0xFF))
            let a = Int(round(rgbColor.alphaComponent * 0xFF))
            
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        }
        
        // Hex初始化方法
        convenience init?(hex: String) {
            let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            var int = UInt64()
            Scanner(string: hex).scanHexInt64(&int)
            
            let a, r, g, b: UInt64
            switch hex.count {
            case 3: // RGB (12-bit)
                (r, g, b, a) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17, 255)
            case 6: // RGB (24-bit)
                (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
            case 8: // RGBA (32-bit)
                (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
            default:
                return nil
            }
            
            self.init(
                red: CGFloat(r) / 255,
                green: CGFloat(g) / 255,
                blue: CGFloat(b) / 255,
                alpha: CGFloat(a) / 255
            )
        }
    
    var safeRGBA: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        guard let rgbColor = self.usingColorSpace(.deviceRGB) else {
            return (0, 0, 0, 1)
        }
        return (
            rgbColor.redComponent,
            rgbColor.greenComponent,
            rgbColor.blueComponent,
            rgbColor.alphaComponent
        )
    }
}

struct MacColorPicker: NSViewRepresentable {
    @Binding var color: NSColor
    
    func makeNSView(context: Context) -> NSColorWell {
        let picker = NSColorWell()
        picker.color = color
        picker.action = #selector(Coordinator.colorChanged(_:))
        picker.target = context.coordinator
        return picker
    }
    
    func updateNSView(_ nsView: NSColorWell, context: Context) {
        nsView.color = color
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(color: $color)
    }
    
    class Coordinator {
        var color: Binding<NSColor>
        
        init(color: Binding<NSColor>) {
            self.color = color
        }
        
        @objc func colorChanged(_ sender: NSColorWell) {
            self.color.wrappedValue = sender.color
        }
    }
}


// macOS优化后的界面布局
struct ContentView: View {
    @StateObject private var colorModel = ColorModel()
    
    var body: some View {
//        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 颜色预览
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: colorModel.nsColor))
                        .frame(height: 100)
                        .shadow(radius: 5)
                    
                    // macOS风格的颜色选择器
                    MacColorPicker(color: $colorModel.nsColor)
                        .frame(width: 60, height: 30)
                    
                    // 使用GroupBox替代Section
                    GroupBox(label: Text("RGB")) {
                        ColorSlider(value: $colorModel.rgb.r, range: 0...255, label: "Red", format: "%d")
                        ColorSlider(value: $colorModel.rgb.g, range: 0...255, label: "Green", format: "%d")
                        ColorSlider(value: $colorModel.rgb.b, range: 0...255, label: "Blue", format: "%d")
                        ColorSlider(value: $colorModel.rgb.a, range: 0...1, label: "Alpha", format: "%d")
                    }
                    GroupBox(label: Text("HEX")) {
                        TextField("#RRGGBBAA", text: $colorModel.hexString)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: colorModel.hexString) { newValue in
                                if let newColor = NSColor(hex: newValue) {
                                    colorModel.nsColor = newColor
                                }
                            }
                            .onSubmit {
                                if NSColor(hex: colorModel.hexString) == nil {
                                    colorModel.hexString = colorModel.nsColor.toHexString()
                                }
                            }
                            .padding(.vertical, 4)
                    }
                    
                    // 在ContentView的VStack中添加以下组件
                    GroupBox(label: Text("HSB")) {
                        ColorSlider(value: $colorModel.hsb.h,
                                    range: 0...1,
                                    label: "Hue",
                                    format: "%.2f",
                                    transform: { $0 * 360 })
                        
                        ColorSlider(value: $colorModel.hsb.s,
                                    range: 0...1,
                                    label: "Saturation",
                                    format: "%.0f%%",
                                    transform: { $0 * 100 })
                        
                        ColorSlider(value: $colorModel.hsb.b,
                                    range: 0...1,
                                    label: "Brightness",
                                    format: "%.0f%%",
                                    transform: { $0 * 100 })
                    }

                    GroupBox(label: Text("CIELAB")) {
                        ColorSlider(value: $colorModel.lab.l,
                                    range: 0...100,
                                    label: "L*",
                                    format: "%.1f")
                        
                        ColorSlider(value: $colorModel.lab.a,
                                    range: -128...127,
                                    label: "a*",
                                    format: "%.1f")
                        
                        ColorSlider(value: $colorModel.lab.b,
                                    range: -128...127,
                                    label: "b*",
                                    format: "%.1f")
                    }

                    GroupBox(label: Text("CMYK")) {
                        ColorSlider(value: $colorModel.cmyk.c,
                                    range: 0...100,
                                    label: "Cyan",
                                    format: "%.1f%%")
                        
                        ColorSlider(value: $colorModel.cmyk.m,
                                    range: 0...100,
                                    label: "Magenta",
                                    format: "%.1f%%")
                        
                        ColorSlider(value: $colorModel.cmyk.y,
                                    range: 0...100,
                                    label: "Yellow",
                                    format: "%.1f%%")
                        
                        ColorSlider(value: $colorModel.cmyk.k,
                                    range: 0...100,
                                    label: "Black",
                                    format: "%.1f%%")
                    }

                    // 更新ColorSlider组件以支持格式化
                    

                    // 在HEX输入部分添加完整实现
                    GroupBox(label: Text("HEX")) {
                        TextField("#RRGGBBAA", text: $colorModel.hexString)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: colorModel.hexString) { newValue in
                                if let newColor = NSColor(hex: newValue) {
                                    colorModel.nsColor = newColor
                                }
                            }
                            .onSubmit {
                                if NSColor(hex: colorModel.hexString) == nil {
                                    colorModel.hexString = colorModel.nsColor.toHexString()
                                }
                            }
                            .padding(.vertical, 4)
                    }

                    

                }
                .padding()
                
            }
            .navigationTitle("Color Inspector")
            .frame(minWidth: 400, idealWidth: 500, maxWidth: .infinity,
                   minHeight: 500, idealHeight: 600, maxHeight: .infinity)
//        }
    }
}
extension Color {
    init(nsColor: NSColor) {
        self.init(nsColor)
    }
}

// 添加菜单栏功能
struct AppMenu: Commands {
    @ObservedObject var model: ColorModel
    
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Copy Hex") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(model.hexString, forType: .string)
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
        }
    }
}

 // 颜色历史记录的相等判断
//extension NSColor: Equatable {
//    public static func == (lhs: NSColor, rhs: NSColor) -> Bool {
//        guard let lhsRGB = lhs.usingColorSpace(.deviceRGB),
//              let rhsRGB = rhs.usingColorSpace(.deviceRGB) else { return false }
//        
//        return lhsRGB.redComponent == rhsRGB.redComponent &&
//               lhsRGB.greenComponent == rhsRGB.greenComponent &&
//               lhsRGB.blueComponent == rhsRGB.blueComponent &&
//               lhsRGB.alphaComponent == rhsRGB.alphaComponent
//    }
//}


// 数值格式化扩展
extension CGFloat {
    func rounded(toPlaces places: Int) -> CGFloat {
        let divisor = pow(10.0, CGFloat(places))
        return (self * divisor).rounded() / divisor
    }
}

extension NSPasteboard.PasteboardType {
    static let color = NSPasteboard.PasteboardType("NSColor")
}


#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
