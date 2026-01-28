import Foundation
import Combine

@MainActor // Ensure UI updates on main thread if observing, but this is a singleton.
class RouteCacheService: ObservableObject {
    static let shared = RouteCacheService()
    
    // In-memory cache for speed
    @Published var history: [RouteHistoryItem] = []
    
    // Separate source of truth for stats (since history might be filtered/deleted locally)
    @Published var lifetimeStats: APIService.UserStats = APIService.UserStats(totalTrips: 0, totalSavings: 0.0)
    
    // Persist to disk just in case offline, but truth is backend
    private let historyKey = "route_history"
    
    private init() {
        loadLocalHistory()
    }
    
    func refreshHistory() {
        guard let userId = AuthService.shared.userId else { return }
        Task {
            do {
                // Fetch both History and Stats
                async let fetchedHistory = APIService.shared.getPlans(userId: userId)
                async let fetchedStats = APIService.shared.getStats(userId: userId)
                
                let (items, stats) = try await (fetchedHistory, fetchedStats)
                
                DispatchQueue.main.async {
                    self.history = items
                    self.lifetimeStats = stats // Update stats from backend aggregation
                    self.saveLocalHistory(items)
                }
            } catch {
                print("Failed to fetch history/stats: \(error)")
            }
        }
    }
    
    func saveRoute(_ route: RouteDetails) async {
        guard let userId = AuthService.shared.userId else {
            print("Cannot save plan: No User ID")
            return
        }
        
        do {
            // Save to Backend
            let planId = try await APIService.shared.savePlan(userId: userId, route: route)
            
            // Construct Item locally for immediate UI update
            let newItem = RouteHistoryItem(id: planId, route: route, date: Date(), status: "active")
            
            await MainActor.run {
                // Prepend
                self.history.insert(newItem, at: 0)
                self.saveLocalHistory(self.history)
            }
        } catch {
            print("Failed to save plan remote: \(error)")
            // Fallback: Save locally?
        }
    }
    
    func getLastRoute() -> RouteDetails? {
        return history.first(where: { $0.status == "active" })?.route
    }
    
    func completePlan(id: String, checkedItems: Set<String>) {
        guard let activeItem = history.first(where: { $0.id == id }) else { return }
        
        // Filter Route to only checked items
        var newStops: [RouteStore] = []
        for stop in activeItem.route.stops {
            let purchasedItems = stop.items.filter { checkedItems.contains($0.id) }
            if !purchasedItems.isEmpty {
                var newStop = stop
                newStop.items = purchasedItems
                newStops.append(newStop)
            }
        }
        
        var finalRoute = activeItem.route
        finalRoute.stops = newStops
        
        // Recalculate total savings for the finalized route
        let newTotalSavings = newStops.flatMap { $0.items }.reduce(0.0) { $0 + $1.savings }
        finalRoute.totalSavings = newTotalSavings
        
        Task {
            do {
                try await APIService.shared.completePlan(planId: activeItem.id, finalRoute: finalRoute)
                DispatchQueue.main.async {
                    if let index = self.history.firstIndex(where: { $0.id == activeItem.id }) {
                        self.history[index].status = "completed"
                        self.history[index].route = finalRoute // Update local history too
                        self.saveLocalHistory(self.history)
                    }
                }
            } catch {
                print("Failed to complete plan: \(error)")
            }
        }
    }
    
    func deletePlan(id: String) {
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }
        
        // Remove from local memory
        history.remove(at: index)
        saveLocalHistory(history)
        
        // Call backend to delete
        Task {
            do {
                try await APIService.shared.deletePlan(planId: id)
            } catch {
                print("Failed to delete plan remote: \(error)")
            }
        }
    }

    private func loadLocalHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let items = try? JSONDecoder().decode([RouteHistoryItem].self, from: data) {
            self.history = items
        }
    }
    
    private func saveLocalHistory(_ items: [RouteHistoryItem]) {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
}
