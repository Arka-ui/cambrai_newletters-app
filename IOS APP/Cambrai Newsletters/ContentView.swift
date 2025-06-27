import SwiftUI
import UIKit
import WebKit
import MapKit
import CoreImage
import EventKit
import UserNotifications

// --- Modes daltoniens ---
enum TriMode: String, CaseIterable {
    case dateDesc = "Plus récent"
    case dateAsc = "Plus ancien"
}

enum TabPage: Int {
    case home = 0
    case settings = 1
}

// --- Fondu + flou pour transition pages ---
struct BlurFadeModifier: ViewModifier {
    let isActive: Bool
    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 1 : 0)
            .blur(radius: isActive ? 0 : 20)
            .animation(.easeInOut(duration: 0.55), value: isActive)
    }
}

// --- Utilitaires daltoniens (matrices) ---
extension Color {
    func colorBlindSim(_ mode: DaltonianMode) -> Color {
        switch mode {
        case .normal:
            return self
        case .protanopia:
            return self.transformColorBlind(matrix: [
                0.567, 0.433, 0.000,
                0.558, 0.442, 0.000,
                0.000, 0.242, 0.758
            ])
        case .deuteranopia:
            return self.transformColorBlind(matrix: [
                0.625, 0.375, 0.000,
                0.700, 0.300, 0.000,
                0.000, 0.300, 0.700
            ])
        case .tritanopia:
            return self.transformColorBlind(matrix: [
                0.950, 0.050, 0.000,
                0.000, 0.433, 0.567,
                0.000, 0.475, 0.525
            ])
        case .protanomaly:
            return self.transformColorBlind(matrix: [
                0.817, 0.183, 0.000,
                0.333, 0.667, 0.000,
                0.000, 0.125, 0.875
            ])
        case .deuteranomaly:
            return self.transformColorBlind(matrix: [
                0.800, 0.200, 0.000,
                0.258, 0.742, 0.000,
                0.000, 0.142, 0.858
            ])
        case .tritanomaly:
            return self.transformColorBlind(matrix: [
                0.967, 0.033, 0.000,
                0.000, 0.733, 0.267,
                0.000, 0.183, 0.817
            ])
        case .achromatopsia, .monochromacy:
            return self.transformColorBlind(matrix: [
                0.299, 0.587, 0.114,
                0.299, 0.587, 0.114,
                0.299, 0.587, 0.114
            ])
        case .achromatomaly:
            return self.transformColorBlind(matrix: [
                0.618, 0.320, 0.062,
                0.163, 0.775, 0.062,
                0.163, 0.320, 0.516
            ])
        }
    }

    private func transformColorBlind(matrix: [Double]) -> Color {
        let components = UIColor(self).cgColor.components ?? [0, 0, 0, 1]
        let r = Double(components[safe: 0] ?? 0)
        let g = Double(components[safe: 1] ?? 0)
        let b = Double(components[safe: 2] ?? 0)
        let newR = matrix[0]*r + matrix[1]*g + matrix[2]*b
        let newG = matrix[3]*r + matrix[4]*g + matrix[5]*b
        let newB = matrix[6]*r + matrix[7]*g + matrix[8]*b
        return Color(red: newR, green: newG, blue: newB)
    }
}

// Pour accès sécurisé à un index de tableau
extension Array {
    subscript(safe index: Int) -> Element? {
        (startIndex..<endIndex).contains(index) ? self[index] : nil
    }
}

// --- Wrapper URL pour zoom image ---
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// --- Tabbar principal avec transitions, filtre daltonien partout ---
struct MainTabBarView: View {
    @State private var selectedPage: TabPage = .home
    @Namespace private var underline
    @AppStorage("selectedThemeID") var selectedThemeID: String = "Island"
    @AppStorage("colorBlindMode") var colorBlindModeRaw: String = "Normal"
    var colorBlindMode: DaltonianMode { DaltonianMode(rawValue: colorBlindModeRaw) ?? .normal }
    var effectiveTheme: AppTheme {
        if colorBlindMode == .normal {
            // Mode normal = thème au choix
            return allThemes.first(where: { $0.id == selectedThemeID }) ?? allThemes[0]
        } else {
            // Sinon = thème daltonien adapté au type choisi
            return daltonianPalettes[colorBlindMode] ?? allThemes[0]
        }
    }


    var body: some View {
        ZStack(alignment: .bottom) {
            // Pages
            ZStack {
                ContentView()
                    .environment(\.colorBlindMode, colorBlindMode)
                    .modifier(BlurFadeModifier(isActive: selectedPage == .home))
                    .zIndex(selectedPage == .home ? 1 : 0)
                SettingsView() // <--- plus d'argument ici !
                    .modifier(BlurFadeModifier(isActive: selectedPage == .settings))
                    .zIndex(selectedPage == .settings ? 1 : 0)
            }
            // Barre basse custom theme
            HStack(spacing: 0) {
                Spacer()
                Button {
                    withAnimation { selectedPage = .home }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(selectedPage == .home ?
                                Color(hex: effectiveTheme.textColor) : Color(hex: effectiveTheme.textColor).opacity(0.5))
                        if selectedPage == .home {
                            Capsule()
                                .fill(Color(hex: effectiveTheme.buttonColor))
                                .frame(width: 28, height: 5)
                        } else {
                            Color.clear.frame(height: 8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                Spacer()
                Button {
                    withAnimation { selectedPage = .settings }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(selectedPage == .settings ?
                                Color(hex: effectiveTheme.textColor) : Color(hex: effectiveTheme.textColor).opacity(0.5))
                        if selectedPage == .settings {
                            Capsule()
                                .fill(Color(hex: effectiveTheme.buttonColor))
                                .frame(width: 28, height: 5)
                        } else {
                            Color.clear.frame(height: 8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                Spacer()
            }
            .frame(height: 66)
            .background(
                ZStack {
                    // Blur glass effect (super clean)
                    VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    // Color glassy overlay selon ton thème (optionnel, léger)
                    LinearGradient(
                        colors: effectiveTheme.resolvedColors.map { $0.colorBlindSim(effectiveTheme.shaderMode) },
                        startPoint: .bottomTrailing, endPoint: .topLeading
                    )
                    .opacity(0.19) // ultra léger, juste pour la teinte
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            .padding(.horizontal, 40)
            .padding(.bottom, 48)
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}

// --- Custom Environment pour accès au mode daltonien dans toutes les sous-vues ---
private struct ColorBlindModeKey: EnvironmentKey {
    static let defaultValue: DaltonianMode = .normal
}
extension EnvironmentValues {
    var colorBlindMode: DaltonianMode {
        get { self[ColorBlindModeKey.self] }
        set { self[ColorBlindModeKey.self] = newValue }
    }
}

// --- Page principale Accueil ---
struct ContentView: View {
    @AppStorage("selectedThemeID") var selectedThemeID: String = "Island"
    @AppStorage("userTextSize") var userTextSize: Double = 18
    @AppStorage("colorBlindMode") var colorBlindModeRaw: String = "Normal"
    @Environment(\.colorBlindMode) var colorBlindMode
    var effectiveTheme: AppTheme {
        if colorBlindMode == .normal {
            return allThemes.first(where: { $0.id == selectedThemeID }) ?? allThemes[0]
        } else {
            return daltonianPalettes[colorBlindMode] ?? allThemes[0]
        }
    }

    @State private var recherche: String = ""
    @State private var tri: TriMode = .dateDesc
    @EnvironmentObject var vm: AnnoncesViewModel
    @State private var selectedAnnonce: AnnonceAPI? = nil

    // === Timer pour refresh auto ===
    let refreshTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    var annoncesFiltreesEtTriees: [AnnonceAPI] {
        var filtrées = vm.annonces
        if !recherche.isEmpty {
            let r = recherche.lowercased()
            filtrées = filtrées.filter {
                $0.titre.lowercased().contains(r) ||
                $0.contenu.lowercased().contains(r)
            }
        }
        switch tri {
        case .dateAsc: return filtrées
        case .dateDesc: return filtrées.reversed()
        }
    }

    // ----------- Bouton d'annonce découplé (optimisation compile-time) -----------
    func annonceButton(idx: Int, annonce: AnnonceAPI) -> some View {
        Button {
            selectedAnnonce = annonce
        } label: {
            AnnonceCardViewAPI(
                annonce: annonce,
                effectiveTheme: effectiveTheme,
                userTextSize: userTextSize,
                colorBlindMode: colorBlindMode
            )
            .onAppear {
                // Si tu veux charger plus d'annonces à la fin de la liste, fais-le ici.
                // Par défaut, simple refresh auto en fin de scroll :
                if idx == annoncesFiltreesEtTriees.count - 1 {
                    vm.fetchAnnonces()
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // -----------------------------------------------------------------------------

    var body: some View {
        ZStack {
            LinearGradient(
                colors: effectiveTheme.resolvedColors.map { $0.colorBlindSim(effectiveTheme.shaderMode) },
                startPoint: .bottomTrailing, endPoint: .topLeading
            ).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    TextField("Rechercher une annonce...", text: $recherche)
                        .padding()
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        .foregroundColor(Color(hex: effectiveTheme.textColor).colorBlindSim(effectiveTheme.shaderMode))
                        .font(.system(size: userTextSize, design: .rounded))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: effectiveTheme.buttonColor).opacity(0.3), lineWidth: 1)
                        )
                    Menu {
                        ForEach(TriMode.allCases, id: \.self) { mode in
                            Button { tri = mode } label: {
                                Text(mode.rawValue)
                            }
                        }
                    } label: {
                        Text(tri.rawValue)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(Color(hex: effectiveTheme.buttonColor).opacity(0.15))
                            .cornerRadius(10)
                            .foregroundColor(Color(hex: effectiveTheme.textColor).colorBlindSim(effectiveTheme.shaderMode))
                    }
                }
                .padding()
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(Array(annoncesFiltreesEtTriees.enumerated()), id: \.1.id) { idx, annonce in
                            annonceButton(idx: idx, annonce: annonce)
                        }
                        if vm.isLoading {
                            ProgressView().padding()
                        }
                    }
                    .padding(.bottom, 10)
                }
                .onAppear { if vm.annonces.isEmpty { vm.fetchAnnonces() } }
            }
            .sheet(item: $selectedAnnonce) { annonce in
                DetailAnnonceViewAPI(
                    annonce: annonce,
                    effectiveTheme: effectiveTheme,
                    userTextSize: userTextSize,
                    colorBlindMode: colorBlindMode
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        // === Rafraîchit automatiquement les annonces ===
        .onReceive(refreshTimer) { _ in
            vm.fetchAnnonces()
        }
    }
}

// --- Image avec filtre daltonien ---
struct AsyncDaltonizedImage: View {
    let url: URL?
    let mode: DaltonianMode
    var body: some View {
        if let url = url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    if mode == .normal {
                        image.resizable()
                    } else {
                        if let uiImage = image.asUIImage(),
                           let filtered = DaltonizedImageHelper.daltonizeImage(uiImage: uiImage, mode: mode) {
                            Image(uiImage: filtered)
                                .resizable()
                        } else {
                            image.resizable()
                        }
                    }
                default:
                    Image(systemName: "photo")
                        .resizable()
                }
            }
        } else {
            Image(systemName: "photo")
                .resizable()
        }
    }
}

// --- Carte d'annonce (API) ---
struct AnnonceCardViewAPI: View {
    let annonce: AnnonceAPI
    let effectiveTheme: AppTheme
    let userTextSize: Double
    let colorBlindMode: DaltonianMode

    var imageURL: URL? {
        annonce.images.first.flatMap { URL(string: $0) }
    }
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(annonce.titre)
                    .font(.system(size: userTextSize + 2, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: effectiveTheme.textColor).colorBlindSim(effectiveTheme.shaderMode))
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(hex: effectiveTheme.textColor).opacity(0.2))
                Text(annonce.contenu)
                    .font(.system(size: userTextSize, design: .monospaced))
                    .foregroundColor(Color(hex: effectiveTheme.textColor).colorBlindSim(effectiveTheme.shaderMode))
                    .lineLimit(2)
            }
            Spacer()
            if let url = imageURL {
                AsyncDaltonizedImage(url: url, mode: colorBlindMode)
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .background(Color(hex: effectiveTheme.buttonColor).opacity(0.8))
                    .cornerRadius(10)
            } else {
                Image(systemName: "photo")
                    .resizable().scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(Color(hex: effectiveTheme.buttonColor).opacity(0.8))
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: effectiveTheme.buttonColor).opacity(0.15))
        )
        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
        .padding(.horizontal)
    }
}

// --- Détail d'une annonce (API) ---
struct DetailAnnonceViewAPI: View {
    let annonce: AnnonceAPI
    let effectiveTheme: AppTheme
    let userTextSize: Double
    let colorBlindMode: DaltonianMode
    @Environment(\.dismiss) var dismiss
    @State private var imageToZoom: IdentifiableURL? = nil
    @State private var showReminderSheet = false

    // ZOOM STATE
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: effectiveTheme.resolvedColors.map { $0.colorBlindSim(effectiveTheme.shaderMode) },
                startPoint: .top,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()
            ZoomScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Color(hex: effectiveTheme.buttonColor))
                                .padding()
                        }
                    }

                    // === Bouton Rappel ===
                    Button {
                        showReminderSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "bell.badge")
                            Text("Rappel")
                        }
                        .padding(10)
                        .foregroundColor(.white)
                        .background(Color.blue.gradient)
                        .cornerRadius(10)
                        .font(.system(size: userTextSize, weight: .bold, design: .rounded))
                    }
                    .sheet(isPresented: $showReminderSheet) {
                        ReminderSheetView(
                            annonce: annonce,
                            effectiveTheme: effectiveTheme,
                            userTextSize: userTextSize
                        )
                    }
                    
                    // === Titre ===
                    Text(annonce.titre)
                        .font(.system(size: userTextSize + 6, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: effectiveTheme.textColor).colorBlindSim(effectiveTheme.shaderMode))

                    // === Contenu ===
                    Text(annonce.contenu)
                        .font(.system(size: userTextSize, design: .monospaced))
                        .foregroundColor(Color(hex: effectiveTheme.textColor).colorBlindSim(effectiveTheme.shaderMode))

                    // === Images ===
                    if !annonce.images.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(annonce.images, id: \.self) { path in
                                    let url = URL(string: "https://amusing-eagle-kindly.ngrok-free.app\(path)")
                                    AsyncDaltonizedImage(url: url, mode: colorBlindMode)
                                        .scaledToFill()
                                        .frame(width: 180, height: 180)
                                        .background(Color(hex: effectiveTheme.buttonColor).opacity(0.6))
                                        .cornerRadius(20)
                                        .onTapGesture {
                                            if let url = url { imageToZoom = IdentifiableURL(url: url) }
                                        }
                                }
                            }
                        }
                    } else {
                        Image(systemName: "photo")
                            .resizable().scaledToFit()
                            .frame(width: 120, height: 120)
                            .foregroundColor(Color(hex: effectiveTheme.buttonColor).opacity(0.8))
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }

                    // === Vidéos YouTube (tous les liens, robustesse) ===
                    let allYoutubeLinks = annonce.allYoutubeLinks
                    if !allYoutubeLinks.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("🎬 Vidéos YouTube :")
                                .font(.system(size: userTextSize - 2, weight: .medium, design: .rounded))
                                .foregroundColor(.red)
                            ForEach(allYoutubeLinks, id: \.self) { yt in
                                if let videoID = extractYoutubeID(from: yt) {
                                    YoutubePlayerView(videoID: videoID)
                                        .frame(height: 220)
                                        .cornerRadius(16)
                                        .shadow(radius: 6)
                                        .padding(.bottom, 6)
                                }
                            }
                        }
                    }

                    // === Carte (adresses multiples) ===
                    if let adresses = annonce.adresses, !adresses.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("🏠 Adresses sur la carte :")
                                .font(.system(size: userTextSize - 2, weight: .semibold, design: .rounded))
                                .foregroundColor(.cyan)
                            // Correction split : on remplace \r\n par \n puis split
                            let cleanedAdresses = adresses.replacingOccurrences(of: "\r\n", with: "\n")
                            MultiAddressMapView(addresses: cleanedAdresses.split(separator: "\n").map { String($0) })
                                .frame(height: 240)
                                .cornerRadius(18)
                                .shadow(radius: 6)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .sheet(item: $imageToZoom) { identifiableURL in
                ZoomableImageView(url: identifiableURL.url, colorBlindMode: colorBlindMode)
            }
        }
    }

}

// --- Image zoomable plein écran (pinch + drag to close) ---
struct ZoomableImageView: View, Identifiable {
    let url: URL
    let colorBlindMode: DaltonianMode
    var id: URL { url }
    @Environment(\.dismiss) var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AsyncDaltonizedImage(url: url, mode: colorBlindMode)
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = max(1, min(lastScale * value, 5))
                        }
                        .onEnded { value in
                            lastScale = max(1, min(scale, 5))
                        }
                )
                .animation(.spring(), value: scale)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 32, weight: .bold))
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
}

// --- Palette spéciale pour daltoniens (exemple, à adapter) ---
// Exemples : adapte/peaufine si tu veux

let daltonianPalettes: [DaltonianMode: AppTheme] = [
    // Vision normale (pas touché)
    .normal: AppTheme(
        id: "DaltonianNormal",
        gradientColors: ["#6A5ACD", "#32CD32"], // Violet-bleu & vert clair
        textColor: "#232526",
        buttonColor: "#6A5ACD",
        shaderMode: .normal
    ),
    // Protanopie : insensibilité rouge (utilise bleu, jaune, turquoise)
    .protanopia: AppTheme(
        id: "DaltonianProtanopia",
        gradientColors: ["#0072B2", "#F0E442"], // Bleu pétant & jaune soleil
        textColor: "#232526",
        buttonColor: "#009E73", // Vert turquoise
        shaderMode: .normal
    ),
    // Deutéranopie : insensibilité vert (utilise bleu, orange, rose vif)
    .deuteranopia: AppTheme(
        id: "DaltonianDeuteranopia",
        gradientColors: ["#56B4E9", "#E69F00"], // Bleu clair & orange doux
        textColor: "#232526",
        buttonColor: "#CC79A7", // Rose/mauve
        shaderMode: .normal
    ),
    // Tritanopie : insensibilité bleu (utilise rose, vert clair, orange)
    .tritanopia: AppTheme(
        id: "DaltonianTritanopia",
        gradientColors: ["#D55E00", "#009E73"], // Orange & vert turquoise
        textColor: "#232526",
        buttonColor: "#F0E442", // Jaune
        shaderMode: .normal
    ),
    // Protanomalie : rouge “pâle” (boost violet/orange)
    .protanomaly: AppTheme(
        id: "DaltonianProtanomaly",
        gradientColors: ["#6A5ACD", "#FFB000"], // Violet et orange-or
        textColor: "#232526",
        buttonColor: "#009E73", // Vert turquoise
        shaderMode: .normal
    ),
    // Deutéranomalie : vert “pâle” (boost bleu/jaune)
    .deuteranomaly: AppTheme(
        id: "DaltonianDeuteranomaly",
        gradientColors: ["#0072B2", "#FFD700"], // Bleu et jaune doré
        textColor: "#232526",
        buttonColor: "#CC79A7", // Rose/mauve
        shaderMode: .normal
    ),
    // Tritanomalie : bleu “pâle” (boost orange/vert)
    .tritanomaly: AppTheme(
        id: "DaltonianTritanomaly",
        gradientColors: ["#E69F00", "#009E73"], // Orange & vert turquoise
        textColor: "#232526",
        buttonColor: "#56B4E9", // Bleu ciel
        shaderMode: .normal
    ),
    // Achromatopsie : vision noir et blanc pur (contraste max)
    .achromatopsia: AppTheme(
        id: "DaltonianAchromatopsia",
        gradientColors: ["#FFFFFF", "#232526"], // Blanc → noir
        textColor: "#232526",
        buttonColor: "#757575", // Gris foncé
        shaderMode: .normal
    ),
    // Achromatomalie : presque N/B (met des gris, jamais de couleurs franches)
    .achromatomaly: AppTheme(
        id: "DaltonianAchromatomaly",
        gradientColors: ["#F0F0F0", "#A9A9A9"], // Gris clair → gris foncé
        textColor: "#232526",
        buttonColor: "#424242", // Gris médium
        shaderMode: .normal
    ),
    // Monochromacie : vision “gris sale” (aplat gris et contraste)
    .monochromacy: AppTheme(
        id: "DaltonianMonochromacy",
        gradientColors: ["#EDEDED", "#333333"], // Gris clair → noir
        textColor: "#232526",
        buttonColor: "#000000", // Noir
        shaderMode: .normal
    )
]


struct SettingsView: View {
    @AppStorage("selectedThemeID") var selectedThemeID: String = "Island"
    @AppStorage("userTextSize") var userTextSize: Double = 18
    @AppStorage("colorBlindMode") var colorBlindModeRaw: String = "Normal"

    var colorBlindMode: DaltonianMode { DaltonianMode(rawValue: colorBlindModeRaw) ?? .normal }
    var effectiveTheme: AppTheme {
        if colorBlindMode == .normal {
            // Mode normal = thème au choix
            return allThemes.first(where: { $0.id == selectedThemeID }) ?? allThemes[0]
        } else {
            // Sinon = thème daltonien adapté au type choisi
            return daltonianPalettes[colorBlindMode] ?? allThemes[0]
        }
    }


    @State private var showAboutSheet = false

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: effectiveTheme.resolvedColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {
                    Text("🎨 Choisir un thème")
                        .font(.title2)
                        .bold()
                        .foregroundColor(Color(hex: effectiveTheme.textColor))

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 18)], spacing: 18) {
                        ForEach(allThemes) { theme in
                            VStack(spacing: 5) {
                                LinearGradient(
                                    colors: theme.resolvedColors,
                                    startPoint: .bottomTrailing,
                                    endPoint: .topLeading
                                )
                                .frame(height: 50)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedThemeID == theme.id ? Color(hex: theme.buttonColor) : .clear, lineWidth: 4)
                                )
                                .onTapGesture { if colorBlindMode == .normal { selectedThemeID = theme.id } }
                                .opacity(colorBlindMode == .normal ? 1.0 : 0.3)
                                Text(theme.id)
                                    .font(.caption)
                                    .foregroundColor(Color(hex: theme.textColor))
                            }
                        }
                    }
                    .padding(.horizontal)

                    // --- Slider taille texte ---
                    VStack(spacing: 10) {
                        HStack {
                            Text("Taille du texte")
                                .foregroundColor(Color(hex: effectiveTheme.textColor))
                                .font(.system(size: 16, weight: .medium))
                            Spacer()
                            Text("\(Int(userTextSize))pt")
                                .foregroundColor(Color(hex: effectiveTheme.textColor).opacity(0.8))
                                .font(.system(size: 15, weight: .regular))
                        }
                        Slider(value: $userTextSize, in: 12...32, step: 1)
                            .accentColor(Color(hex: effectiveTheme.buttonColor))
                        Text("Ceci est un texte d’exemple.")
                            .foregroundColor(Color(hex: effectiveTheme.textColor))
                            .font(.system(size: userTextSize, weight: .medium))
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 12)

                    // --- Mode daltonien ---
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Mode daltonien")
                            .foregroundColor(Color(hex: effectiveTheme.textColor))
                            .font(.system(size: 16, weight: .medium))
                        Picker("Mode daltonien", selection: $colorBlindModeRaw) {
                            ForEach(DaltonianMode.allCases) { mode in
                                Text(mode.label).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .accentColor(Color(hex: effectiveTheme.buttonColor))
                        
                        if colorBlindMode != .normal {
                            Text("🌈 Les couleurs de l'interface sont adaptées pour être facilement distinguées avec ce mode de vision. Les dégradés, boutons et textes garantissent un contraste maximal. \n\nDésactive ce mode pour revenir aux thèmes classiques.")
                                .font(.footnote)
                                .foregroundColor(Color(hex: effectiveTheme.textColor).opacity(0.8))
                                .padding(.top, 2)
                        } else {
                            Text("Le mode daltonien applique un thème de couleurs spécialement choisi pour chaque type de daltonisme.")
                                .font(.footnote)
                                .foregroundColor(Color(hex: effectiveTheme.textColor).opacity(0.7))
                                .padding(.top, 2)
                        }
                    }
                    .padding(.horizontal, 12)

                    Spacer().frame(height: 100)
                }
                .padding(.vertical)
            }

            Button {
                showAboutSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                    Text("À propos")
                        .fontWeight(.semibold)
                }
                .foregroundColor(Color(hex: effectiveTheme.buttonColor))
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.07))
                .cornerRadius(17)
                .padding(.horizontal, 24)
                .padding(.bottom, 130)
            }
            .ignoresSafeArea(.keyboard)
            .sheet(isPresented: $showAboutSheet) {
                AboutSheetView(effectiveTheme: effectiveTheme)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

// --- Vue pour la popup crédits ---
struct AboutSheetView: View {
    let effectiveTheme: AppTheme
    var body: some View {
        ZStack {
            LinearGradient(
                colors: effectiveTheme.resolvedColors,
                startPoint: .top, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Spacer()
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(Color(hex: effectiveTheme.buttonColor))
                        Spacer()
                    }
                    Text("À propos de l’application")
                        .font(.title2).bold()
                        .foregroundColor(Color(hex: effectiveTheme.textColor))

                    // === Mets ici tout ton texte de crédits et d’infos ! ===
                    Text("""
                    Développé par Eddy  
                    Version 0.9.6

                    **Crédits et ressources utilisées :**

                    - **YouTube** — Service d’hébergement et de partage de vidéos (API intégrée pour l’affichage des vidéos).
                    - **Apple Maps** — Intégration des cartes et géocodage pour l’affichage des adresses.
                    - **EventKit (Apple)** — Utilisé pour l’ajout de rappels et d’événements dans le calendrier natif iOS.
                    - **UserNotifications (Apple)** — Système de notifications locales pour les rappels court terme.
                    - **Ngrok** — Service de tunnel sécurisé utilisé pour héberger temporairement les images (test/dev).
                    - **SwiftUI & UIKit** — Frameworks Apple pour toute l’interface et l’expérience utilisateur.
                    - **OpenAI Codex** — Assistance IA pour l'optimisation du code.
                    - **Icones Apple SF Symbols** — Pour les icônes de l’interface.

                    Toutes les marques et services cités sont la propriété de leurs détenteurs respectifs.
                    """)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color(hex: effectiveTheme.textColor))

                    // === Mets ici tes liens, réseaux, etc. ===
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Liens utiles :")
                            .bold()
                            .foregroundColor(Color(hex: effectiveTheme.textColor))
                        Link("Site de la mairie de Cambrai", destination: URL(string: "https://www.villedecambrai.com")!)
                        // Ajoute tes liens ici !
                    }
                    .font(.system(size: 15))

                    Spacer()
                }
                .padding()
            }
        }
    }
}

// --- Pastel color name helper (hors struct!) ---
func pastelColorName(idx: Int) -> String {
    let names = [
        "Rouge pastel", "Pêche", "Jaune pastel", "Vert clair", "Bleu clair", "Lavande", "Blanc",
        "Rose clair", "Bleu lavande", "Vert d’eau", "Vert pistache", "Abricot", "Rose doux", "Violet doux",
        "Jaune crème", "Bleu ciel", "Menthe"
    ]
    return names[safe: idx] ?? "Couleur"
}

// --- Image processing helper, version CIColorMatrix compatible partout ---
struct DaltonizedImageHelper {
    static func daltonizeImage(uiImage: UIImage, mode: DaltonianMode) -> UIImage? {
        guard let cgImage = uiImage.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIColorMatrix") else { return uiImage }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        switch mode {
        case .protanopia:
            filter.setValue(CIVector(x: 0.567, y: 0.433, z: 0, w: 0), forKey: "inputRVector")
            filter.setValue(CIVector(x: 0.558, y: 0.442, z: 0, w: 0), forKey: "inputGVector")
            filter.setValue(CIVector(x: 0, y: 0.242, z: 0.758, w: 0), forKey: "inputBVector")
        case .deuteranopia:
            filter.setValue(CIVector(x: 0.625, y: 0.375, z: 0, w: 0), forKey: "inputRVector")
            filter.setValue(CIVector(x: 0.7, y: 0.3, z: 0, w: 0), forKey: "inputGVector")
            filter.setValue(CIVector(x: 0, y: 0.3, z: 0.7, w: 0), forKey: "inputBVector")
        case .tritanopia:
            filter.setValue(CIVector(x: 0.95, y: 0.05, z: 0, w: 0), forKey: "inputRVector")
            filter.setValue(CIVector(x: 0, y: 0.433, z: 0.567, w: 0), forKey: "inputGVector")
            filter.setValue(CIVector(x: 0, y: 0.475, z: 0.525, w: 0), forKey: "inputBVector")
        default:
            return uiImage // Les autres modes à coder si besoin
        }
        let context = CIContext()
        guard let output = filter.outputImage,
              let cgimg = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgimg)
    }
}

extension Image {
    func asUIImage() -> UIImage? {
        let controller = UIHostingController(rootView: self.resizable())
        let view = controller.view

        let targetSize = CGSize(width: 180, height: 180) // ou la taille max affichée dans ton UI
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: view?.bounds ?? .zero, afterScreenUpdates: true)
        }
    }
}

struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: effect)
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = effect
    }
}

// Extraction du videoID depuis une URL Youtube (toutes variantes)
func extractYoutubeID(from url: String) -> String? {
    let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let patterns = [
        "(?:youtu.be/|youtube.com/(?:watch\\?v=|embed/|v/|shorts/)?)([\\w-]{11})",
        "youtube.com.*[?&]v=([\\w-]{11})"
    ]
    for pattern in patterns {
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            if let match = regex.firstMatch(in: trimmed, options: [], range: range),
               let idRange = Range(match.range(at: 1), in: trimmed) {
                return String(trimmed[idRange])
            }
        }
    }
    return nil
}

// Player YouTube SwiftUI (WKWebView)
struct YoutubePlayerView: UIViewRepresentable {
    let videoID: String
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.backgroundColor = .clear
        webView.isOpaque = false
        return webView
    }
    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = """
        <html><body style='margin:0;padding:0;background:transparent;'>
        <iframe width='100%' height='100%' src='https://www.youtube.com/embed/\(videoID)?playsinline=1&autoplay=0&modestbranding=1&rel=0' frameborder='0' allowfullscreen style='border-radius:14px;'></iframe>
        </body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}

// --- Identifiable pour coordonnées (map) ---
struct IdentifiableCoordinate: Identifiable {
    let coordinate: CLLocationCoordinate2D
    var id: String { "\(coordinate.latitude)-\(coordinate.longitude)" }
}

// --- Vue Map pour adresse ---
struct MapAddressView: View {
    let address: String
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 50.175, longitude: 3.234), // Cambrai par défaut
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var loading: Bool = true
    @State private var error: Bool = false

    var body: some View {
        ZStack {
            if let coordinate = coordinate {
                Map(coordinateRegion: $region, annotationItems: [IdentifiableCoordinate(coordinate: coordinate)]) { item in
                    MapMarker(coordinate: item.coordinate, tint: .red)
                }
            } else if loading {
                ProgressView("Chargement de la carte…")
            } else if error {
                Text("Adresse introuvable")
                    .foregroundColor(.red)
            }
        }
        .onAppear {
            geocodeAddress()
        }
    }

    func geocodeAddress() {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, err in
            DispatchQueue.main.async {
                loading = false
                if let coord = placemarks?.first?.location?.coordinate {
                    self.coordinate = coord
                    self.region.center = coord
                } else {
                    self.error = true
                }
            }
        }
    }
}

// --- Carte MapKit avec fit all markers et géocodage fiable ---
import MapKit
struct AddressAnnotation: Identifiable, Equatable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
    static func == (lhs: AddressAnnotation, rhs: AddressAnnotation) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.title == rhs.title
    }
}
class MultiAddressMapModel: NSObject, ObservableObject, MKMapViewDelegate {
    @Published var annotations: [AddressAnnotation] = []
    private var lastAddresses: [String] = []
    func geocode(addresses: [String], mapView: MKMapView?) {
        guard addresses != lastAddresses else { return }
        lastAddresses = addresses
        annotations = []
        let geocoder = CLGeocoder()
        var tempAnnotations: [AddressAnnotation] = []
        let group = DispatchGroup()
        for address in addresses where !address.trimmingCharacters(in: .whitespaces).isEmpty {
            group.enter()
            geocoder.geocodeAddressString(address) { placemarks, error in
                defer { group.leave() }
                if let loc = placemarks?.first?.location {
                    let annotation = AddressAnnotation(coordinate: loc.coordinate, title: address)
                    tempAnnotations.append(annotation)
                }
            }
        }
        group.notify(queue: .main) {
            self.annotations = tempAnnotations
            if let mapView = mapView, !tempAnnotations.isEmpty {
                mapView.removeAnnotations(mapView.annotations)
                let mkAnnotations = tempAnnotations.map { ann -> MKPointAnnotation in
                    let a = MKPointAnnotation()
                    a.coordinate = ann.coordinate
                    a.title = ann.title
                    return a
                }
                mapView.addAnnotations(mkAnnotations)
                mapView.showAnnotations(mkAnnotations, animated: true)
            }
        }
    }
}
struct MultiAddressMapView: View {
    let addresses: [String]
    @StateObject private var model = MultiAddressMapViewModel()
    var body: some View {
        Map(coordinateRegion: $model.region, annotationItems: model.coordinates.map { IdentifiableCoordinate(coordinate: $0) }) { item in
            MapMarker(coordinate: item.coordinate, tint: .cyan)
        }
        .onAppear { model.geocodeAll(addresses: addresses) }
        .onChange(of: addresses) { new in model.geocodeAll(addresses: new) }
    }
}

// --- Rappel (EventKit) ---
struct ReminderSheetView: View {
    let annonce: AnnonceAPI
    let effectiveTheme: AppTheme
    let userTextSize: Double

    @Environment(\.presentationMode) var presentationMode

    @State private var selectedHours: Int = 0
    @State private var selectedMinutes: Int = 10

    @State private var reminderType: String = "short"
    @State private var eventDate: Date = Date().addingTimeInterval(3600)
    @State private var calendars: [EKCalendar] = []
    @State private var selectedCalendar: EKCalendar?
    @State private var showCalendarError = false
    @State private var calendarPermissionDenied = false

    var accent: Color { Color(hex: effectiveTheme.buttonColor) }
    var bgGradient: LinearGradient {
        LinearGradient(
            colors: effectiveTheme.resolvedColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            bgGradient.ignoresSafeArea()
            VStack(spacing: 22) {
                // Header
                HStack {
                    Spacer()
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 28))
                        .foregroundColor(accent)
                    Text("Créer un rappel")
                        .font(.system(size: userTextSize + 8, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: effectiveTheme.textColor))
                    Spacer()
                }
                .padding(.top, 16)

                // Type de rappel
                VStack(spacing: 10) {
                    Text("Type de rappel")
                        .font(.system(size: userTextSize + 2, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundColor(Color(hex: effectiveTheme.textColor))
                    HStack(spacing: 0) {
                        Button {
                            reminderType = "short"
                        } label: {
                            HStack {
                                Image(systemName: "clock")
                                Text("Court terme")
                            }
                            .font(.system(size: userTextSize, weight: .semibold))
                            .padding(.vertical, 8).padding(.horizontal, 22)
                            .background(reminderType == "short" ? accent.opacity(0.24) : Color.white.opacity(0.06))
                            .foregroundColor(reminderType == "short" ? accent : Color(hex: effectiveTheme.textColor))
                            .clipShape(Capsule())
                        }
                        Button {
                            reminderType = "long"
                        } label: {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                Text("Long terme")
                            }
                            .font(.system(size: userTextSize, weight: .semibold))
                            .padding(.vertical, 8).padding(.horizontal, 22)
                            .background(reminderType == "long" ? accent.opacity(0.24) : Color.white.opacity(0.06))
                            .foregroundColor(reminderType == "long" ? accent : Color(hex: effectiveTheme.textColor))
                            .clipShape(Capsule())
                        }
                    }
                    .background(Color.black.opacity(0.08))
                    .clipShape(Capsule())
                    .padding(.vertical, 4)
                    
                    Text(reminderType == "short"
                         ? "Envoie une notification locale dans quelques minutes/heures."
                         : "Ajoute un événement à la date de ton choix dans un calendrier de ton appareil.")
                        .font(.system(size: userTextSize - 2, design: .rounded))
                        .foregroundColor(Color(hex: effectiveTheme.textColor).opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
                .background(Color.black.opacity(0.12))
                .cornerRadius(25)

                // Rappel court
                if reminderType == "short" {
                    VStack(spacing: 18) {
                        HStack(alignment: .center, spacing: 18) {
                            Image(systemName: "clock")
                                .foregroundColor(accent)
                                .font(.system(size: 24))
                            Text("Me rappeler dans")
                                .font(.system(size: userTextSize + 2, weight: .semibold))
                                .foregroundColor(Color(hex: effectiveTheme.textColor))
                        }
                        HStack(spacing: 0) {
                            Picker("", selection: $selectedHours) {
                                ForEach(0..<24, id: \.self) { h in
                                    Text("\(h) h").tag(h)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 70, height: 100)
                            .clipped()
                            Picker("", selection: $selectedMinutes) {
                                ForEach(0..<60, id: \.self) { m in
                                    Text("\(m) min").tag(m)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 70, height: 100)
                            .clipped()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .background(Color.black.opacity(0.04))
                        .cornerRadius(18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(accent.opacity(0.18), lineWidth: 1)
                        )
                    }
                    .padding(18)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(24)
                }

                // Rappel long (calendrier)
                if reminderType == "long" {
                    VStack(spacing: 18) {
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: "calendar.badge.plus")
                                .foregroundColor(.blue)
                            Text("Choisir la date")
                                .font(.system(size: userTextSize + 2, weight: .semibold))
                                .foregroundColor(Color(hex: effectiveTheme.textColor))
                        }
                        HStack {
                            DatePicker("", selection: $eventDate)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)

                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                            if calendarPermissionDenied {
                                Text("Permission calendrier refusée. Va dans Réglages > Confidentialité > Calendriers.")
                                    .font(.system(size: userTextSize - 2))
                                    .foregroundColor(.red)
                            } else if calendars.isEmpty {
                                Text("Aucun calendrier disponible. Crée un calendrier dans l'app Calendrier.")
                                    .font(.system(size: userTextSize - 2))
                                    .foregroundColor(.red)
                            } else {
                                Text("Ajouter à ")
                                    .font(.system(size: userTextSize, weight: .semibold))
                                Picker("", selection: $selectedCalendar) {
                                    ForEach(calendars, id: \.self) { cal in
                                        Text(cal.title).tag(cal as EKCalendar?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                    }
                    .padding(18)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(24)
                }

                Spacer()

                Button(action: {
                    if reminderType == "short" {
                        scheduleLocalNotif()
                    } else if reminderType == "long" {
                        addCalendarEvent()
                    }
                }) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Valider le rappel")
                            .fontWeight(.bold)
                    }
                    .font(.system(size: userTextSize, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 40)
                    .background(accent.gradient)
                    .cornerRadius(16)
                    .shadow(color: accent.opacity(0.15), radius: 6, y: 2)
                }
                .padding(.bottom, 18)
                .disabled(
                    reminderType == "long" &&
                    (calendarPermissionDenied || selectedCalendar == nil || calendars.isEmpty)
                )

                if showCalendarError {
                    Text("Erreur lors de l'ajout au calendrier.")
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .onAppear {
                if reminderType == "long" {
                    loadCalendars()
                }
            }
            .onChange(of: reminderType) { newVal in
                if newVal == "long" {
                    loadCalendars()
                }
            }
        }
    }

    // FONCTIONS

    func scheduleLocalNotif() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = annonce.titre
            content.body = annonce.contenu
            content.sound = .default
            let seconds: TimeInterval = Double(selectedHours * 3600 + selectedMinutes * 60)
            if seconds <= 0 { return }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            center.add(request) { _ in
                DispatchQueue.main.async { presentationMode.wrappedValue.dismiss() }
            }
        }
    }

    func loadCalendars() {
        let store = EKEventStore()
        store.requestAccess(to: .event) { granted, _ in
            DispatchQueue.main.async {
                calendarPermissionDenied = !granted
                if granted {
                    let allCals = store.calendars(for: .event)
                    // Ne garde QUE les calendriers écriture locale ou iCloud
                    let writableCalendars = allCals.filter {
                        $0.allowsContentModifications &&
                        ($0.type == .local || $0.type == .calDAV)
                    }
                    calendars = writableCalendars
                    selectedCalendar = writableCalendars.first
                } else {
                    calendars = []
                    selectedCalendar = nil
                }
            }
        }
    }

    func addCalendarEvent() {
        let store = EKEventStore()
        store.requestAccess(to: .event) { granted, _ in
            DispatchQueue.main.async {
                guard granted, let calendar = selectedCalendar else {
                    showCalendarError = true
                    return
                }
                let event = EKEvent(eventStore: store)
                event.title = annonce.titre
                event.notes = annonce.contenu
                event.calendar = calendar
                event.startDate = eventDate
                event.endDate = eventDate.addingTimeInterval(3600)
                do {
                    try store.save(event, span: .thisEvent)
                    presentationMode.wrappedValue.dismiss()
                } catch {
                    showCalendarError = true
                }
            }
        }
    }
}

// --- Bouton stylé pour type de rappel
struct ReminderTypeButton: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let accent: Color
    let linearAccent: LinearGradient
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                Text(label)
                    .font(.system(size: 17, weight: .semibold))
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 17)
            .background(
                isSelected
                ? AnyView(linearAccent)
                : AnyView(Color.clear)
            )
            .foregroundColor(isSelected ? .white : accent)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .shadow(color: isSelected ? accent.opacity(0.10) : .clear, radius: 6, y: 2)
    }
}

// --- Bouton stylé pour minutes/heures ---
struct ReminderUnitButton: View {
    let label: String
    let isActive: Bool
    let accent: Color
    let linearAccent: LinearGradient
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    isActive
                    ? linearAccent
                    : LinearGradient(colors: [.clear, .clear], startPoint: .top, endPoint: .bottom)
                )

                .foregroundColor(isActive ? .white : accent)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .shadow(color: isActive ? accent.opacity(0.12) : .clear, radius: 3, y: 1)
    }
}

extension AnnonceAPI {
    var allYoutubeLinks: [String] {
        var links: [String] = []
        if let y = youtube, !y.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            links.append(y.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let ys = youtubes {
            links.append(contentsOf:
                ys.components(separatedBy: .newlines)
                  .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                  .filter { !$0.isEmpty }
            )
        }
        // Retire les doublons et liens vides
        return Array(Set(links)).filter { !$0.isEmpty }
    }
}

// --- ViewModel robuste pour la carte multi-adresses ---
class MultiAddressMapViewModel: ObservableObject {
    @Published var coordinates: [CLLocationCoordinate2D] = []
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 50.176, longitude: 3.234),
        span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
    )
    func geocodeAll(addresses: [String]) {
        // Nettoyage : trim, suppression des vides, logs
        let cleaned = addresses.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        print("[DEBUG] Adresses à géocoder :", cleaned)
        coordinates = []
        let geocoder = CLGeocoder()
        var found: [CLLocationCoordinate2D] = []
        let group = DispatchGroup()
        for address in cleaned {
            group.enter()
            geocoder.geocodeAddressString(address) { placemarks, _ in
                if let coord = placemarks?.first?.location?.coordinate {
                    found.append(coord)
                } else {
                    print("[DEBUG] Adresse non trouvée :", address)
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            self.coordinates = found
            print("[DEBUG] Coordonnées trouvées :", found)
            if !found.isEmpty {
                let avgLat = found.map { $0.latitude }.reduce(0, +) / Double(found.count)
                let avgLon = found.map { $0.longitude }.reduce(0, +) / Double(found.count)
                self.region.center = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
                self.region.span = MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            }
        }
    }
}
