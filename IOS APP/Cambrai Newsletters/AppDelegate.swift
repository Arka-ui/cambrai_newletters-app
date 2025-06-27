import UIKit
import BackgroundTasks
import UserNotifications

class AppDelegate: UIResponder, UIApplicationDelegate {
    let taskIdentifier = "com.arka.cambrai.fetchAnnonces"
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Enregistre la tâche de fond
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        // Demande la permission de notif
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            // print("Notifications autorisées: \(granted)") // Nettoyage
        }
        scheduleAppRefresh() // Programme la première tâche
        return true
    }
    
    func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh() // reprogramme la prochaine tâche
        let vm = AnnoncesViewModel()
        let operation = BlockOperation {
            let group = DispatchGroup()
            group.enter()
            vm.refreshBackground { _ in group.leave() }
            group.wait()
        }
        task.expirationHandler = {
            operation.cancel()
        }
        operation.completionBlock = {
            task.setTaskCompleted(success: !operation.isCancelled)
        }
        OperationQueue().addOperation(operation)
    }
    
    /// Programme un refresh dans 30 minutes
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 1800) // 30 min
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // print("Impossible de programmer la tâche de fond: \(error)") // Nettoyage
        }
    }
}
