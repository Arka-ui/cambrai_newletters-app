import SwiftUI

@main
struct MyApp: App {
    @StateObject private var annoncesVM = AnnoncesViewModel()
    
    var body: some Scene {
        WindowGroup {
            MainTabBarView()
                .environmentObject(annoncesVM)
        }
    }
}
