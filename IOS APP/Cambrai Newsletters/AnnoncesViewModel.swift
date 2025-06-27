import Foundation
import UserNotifications
import UIKit

// Modèle d'annonce (garde tout)
struct AnnonceAPI: Identifiable, Codable, Equatable {
    let id: String
    let titre: String
    let contenu: String
    let images: [String] // Contiendra des URLs directes
    let youtube: String?
    let adresse: String?
    let tags: String?
    let lieux: String?
    let adresses: String?
    let youtubes: String?
}

class AnnoncesViewModel: ObservableObject {
    @Published var annonces: [AnnonceAPI] = []
    @Published var isLoading = false
    private var lastAnnoncesIDs: Set<String> = []
    
    init() {
        fetchAnnonces()
    }
    
    /// Récupère les annonces depuis l'API distante (FastAPI, nouvelle URL)
    func fetchAnnonces(completion: (([AnnonceAPI]) -> Void)? = nil) {
        isLoading = true
        guard let url = URL(string: "https://amusing-eagle-kindly.ngrok-free.app/api/annonces") else { return }
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let publiees = json["publiees"] as? [[String: Any]] else {
                    self.annonces = []
                    return
                }
                self.annonces = publiees.compactMap { dict in
                    guard let id = dict["id"] as? Int else { return nil }
                    return AnnonceAPI(
                        id: String(id),
                        titre: dict["titre"] as? String ?? "",
                        contenu: dict["contenu"] as? String ?? "",
                        images: dict["images"] as? [String] ?? [],
                        youtube: dict["youtube"] as? String,
                        adresse: dict["adresse"] as? String,
                        tags: dict["tags"] as? String,
                        lieux: dict["lieux"] as? String,
                        adresses: dict["adresses"] as? String,
                        youtubes: dict["youtubes"] as? String
                    )
                }
                completion?(self.annonces)
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
            self.lastAnnoncesIDs = newIDs
        }
    }
    
    private func sendNotificationForNewAnnonces(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Nouvelles annonces !"
        content.body = "Il y a \(count) nouvelle(s) annonce(s) à découvrir."
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
