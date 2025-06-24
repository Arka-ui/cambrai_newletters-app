import SwiftUI

// === Enum DaltonianMode (codable !) ===
enum DaltonianMode: String, CaseIterable, Identifiable, Codable {
    case normal = "Normal"
    case protanopia = "Protanopie"
    case deuteranopia = "Deutéranopie"
    case tritanopia = "Tritanopie"
    case protanomaly = "Protanomalie"
    case deuteranomaly = "Deutéranomalie"
    case tritanomaly = "Tritanomalie"
    case achromatopsia = "Achromatopsie"
    case achromatomaly = "Achromatomalie"
    case monochromacy = "Monochromacie"

    var id: String { self.rawValue }
    var label: String { self.rawValue }
}

// === AppTheme struct ===
struct AppTheme: Identifiable, Codable, Equatable {
    let id: String
    let gradientColors: [String] // HEX strings
    let textColor: String
    let buttonColor: String
    let shaderMode: DaltonianMode

    var resolvedColors: [Color] {
        gradientColors.map { Color(hex: $0) }
    }
}

// === La liste de tous tes thèmes ===
let allThemes: [AppTheme] = [
    // ─── Light Pastels ─── (texte gris foncé)
    AppTheme(
        id: "Desert",
        gradientColors: ["#EDE574", "#E1F5C4"],
        textColor: "#333333",
        buttonColor: "#EDE574",
        shaderMode: .normal
    ),
    AppTheme(
        id: "Island",
        gradientColors: ["#C6FFDD", "#FBD786", "#F7797D"],
        textColor: "#333333",
        buttonColor: "#F7797D",
        shaderMode: .normal
    ),
    AppTheme(
        id: "Lavender",
        gradientColors: ["#B993D6", "#8CA6DB"],
        textColor: "#333333",
        buttonColor: "#8CA6DB",
        shaderMode: .normal
    ),

    // ─── Soft Warms ─── (texte gris foncé)
    AppTheme(
        id: "Coral",
        gradientColors: ["#FF7E5F", "#FEAE96"],
        textColor: "#333333",
        buttonColor: "#FF7E5F",
        shaderMode: .normal
    ),
    AppTheme(
        id: "Peach",
        gradientColors: ["#ED4264", "#FFEDBC"],
        textColor: "#333333",
        buttonColor: "#ED4264",
        shaderMode: .normal
    ),
    AppTheme(
        id: "Aurora",
        gradientColors: ["#FF5F6D", "#FFC371"],
        textColor: "#333333",
        buttonColor: "#FF5F6D",
        shaderMode: .normal
    ),

    // ─── Mint & Bright ─── (texte gris foncé)
    AppTheme(
        id: "Minty",
        gradientColors: ["#A8E063", "#56AB2F"],
        textColor: "#333333",
        buttonColor: "#56AB2F",
        shaderMode: .normal
    ),
    AppTheme(
        id: "Ocean",
        gradientColors: ["#00C9FF", "#92FE9D"],
        textColor: "#333333",
        buttonColor: "#00C9FF",
        shaderMode: .normal
    ),

    // ─── Vibrant Warm ─── (texte blanc marbré)
    AppTheme(
        id: "Sunset",
        gradientColors: ["#8A2387", "#E94057", "#F27121"],
        textColor: "#F0F0F0",
        buttonColor: "#F27121",
        shaderMode: .normal
    ),

    // ─── Mids & Darks ─── (texte blanc marbré)
    AppTheme(
        id: "Mermaid",
        gradientColors: ["#aa4b6b", "#3b8d99"],
        textColor: "#F0F0F0",
        buttonColor: "#3b8d99",
        shaderMode: .normal
    ),
    AppTheme(
        id: "Forest",
        gradientColors: ["#134E5E", "#71B280"],
        textColor: "#F0F0F0",
        buttonColor: "#71B280",
        shaderMode: .normal
    ),
    AppTheme(
        id: "Galaxy",
        gradientColors: ["#2C3E50", "#4CA1AF"],
        textColor: "#F0F0F0",
        buttonColor: "#4CA1AF",
        shaderMode: .normal
    ),
    AppTheme(
        id: "Deep",
        gradientColors: ["#1f4037", "#99f2c8"],
        textColor: "#F0F0F0",
        buttonColor: "#1f4037",
        shaderMode: .normal
    ),
    AppTheme(
        id: "Yoda",
        gradientColors: ["#FF0099", "#493240"],
        textColor: "#F0F0F0",
        buttonColor: "#FF0099",
        shaderMode: .normal
    ),
    AppTheme(
        id: "Midnight",
        gradientColors: ["#232526", "#414345"],
        textColor: "#F0F0F0",
        buttonColor: "#414345",
        shaderMode: .normal
    ),
    AppTheme(
        id: "Summer",
        gradientColors: ["#FFEE58", "#29B6F6", "#FF7043"],  // jaune soleil → bleu ciel → corail plage
        textColor: "#333333",                                // gris foncé pour le contraste
        buttonColor: "#FFEE58",                              // accent soleil pour les boutons
        shaderMode: .normal
    ),
    AppTheme(
        id: "Éclipse",
        gradientColors: ["#9B30FF", "#232526", "#F0F0F0"], // mauve vif → quasi-noir → blanc marbré
        textColor: "#F0F0F0",                              // blanc marbré pour le contraste
        buttonColor: "#9B30FF",                            // accent mauve
        shaderMode: .normal
    )
]


// === Extension HEX vers Color ===
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
