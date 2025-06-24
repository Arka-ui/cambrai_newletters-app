import Foundation
import UserNotifications
import UIKit

// Modèle d'annonce (garde tout)
struct AnnonceAPI: Identifiable, Codable, Equatable {
    let id: Int
    let titre: String
    let contenu: String
    let images: [String]
    let youtube: String?
    let adresse: String?
}

class AnnoncesViewModel: ObservableObject {
    @Published var annonces: [AnnonceAPI] = []
    @Published var isLoading = false
    
    // ==== CORRECTION : Set<Int> et plus Set<String>
    private var lastAnnoncesIDs: Set<Int> = []
    private var lastFetchDate: Date? = nil
    
    // À changer selon ton endpoint
    let apiURL = URL(string: "https://fca3-92-175-138-153.ngrok-free.app/api/annonces_publiees")!
    
    init() {
        fetchAnnonces()
    }
    
    /// Récupère les annonces depuis l'API (appelé à l'init ou manuellement)
    func fetchAnnonces(completion: (([AnnonceAPI]) -> Void)? = nil) {
        guard !isLoading else { return }
        isLoading = true
        let task = URLSession.shared.dataTask(with: apiURL) { [weak self] data, response, error in
            defer { DispatchQueue.main.async { self?.isLoading = false } }
            guard let data = data, error == nil else { return }
            let decoder = JSONDecoder()
            if let nouvelles = try? decoder.decode([AnnonceAPI].self, from: data) {
                DispatchQueue.main.async {
                    let newIDs = Set(nouvelles.map { $0.id })
                    if !self!.lastAnnoncesIDs.isEmpty && newIDs != self!.lastAnnoncesIDs {
                        self?.sendNotifIfNeeded(oldIDs: self!.lastAnnoncesIDs, newAnnonces: nouvelles)
                    }
                    self?.annonces = nouvelles
                    self?.lastAnnoncesIDs = newIDs
                    self?.lastFetchDate = Date()
                    completion?(nouvelles)
                }
            }
        }
        task.resume()
    }
    
    /// Refresh manuel (ex : pour bouton refresh UI)
    func refresh() {
        fetchAnnonces()
    }
    
    /// Pour background fetch (utilisé dans AppDelegate)
    func refreshBackground(completion: ((UIBackgroundFetchResult) -> Void)? = nil) {
        fetchAnnonces { newAnnonces in
            let newIDs = Set(newAnnonces.map { $0.id })
            let nouveautes = newIDs.subtracting(self.lastAnnoncesIDs)
            if !nouveautes.isEmpty {
                self.sendNotificationForNewAnnonces(count: nouveautes.count)
                completion?(.newData)
            } else {
                completion?(.noData)
            }
            self.annonces = newAnnonces
            self.lastAnnoncesIDs = newIDs
        }
    }
    
    // ========== Notifications locales ==========
    private func sendNotificationForNewAnnonces(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Nouvelle(s) annonce(s) !"
        content.body = "Il y a \(count) nouvelle(s) annonce(s) depuis ta dernière visite."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    // ==== CORRECTION : oldIDs est Set<Int> et on compare à id (Int)
    private func sendNotifIfNeeded(oldIDs: Set<Int>, newAnnonces: [AnnonceAPI]) {
        let newOnly = newAnnonces.filter { !oldIDs.contains($0.id) }
        guard !newOnly.isEmpty else { return }
        let content = UNMutableNotificationContent()
        content.title = "Nouvelles annonces"
        if newOnly.count == 1 {
            content.body = newOnly.first?.titre ?? "Nouvelle annonce !"
        } else {
            content.body = "\(newOnly.count) nouvelles annonces publiées !"
        }
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        // ==== CORRECTION : ID doit être String (donc String(id) si jamais tu veux mettre l'ID, ici UUID pour éviter doublons)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
