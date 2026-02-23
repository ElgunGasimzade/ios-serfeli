import SwiftUI

struct ActiveRouteScreen: View {
    let routeId: String
    var preloadedRoute: RouteDetails? = nil // Optional preloaded data
    var planId: String? = nil // Optional Plan ID if this is a saved plan
    
    @State private var route: RouteDetails?
    @State private var isLoading = true
    @State private var checkedItems: Set<String> = []
    @State private var initiallyCheckedItems: Set<String> = []
    @EnvironmentObject var localization: LocalizationManager
    
    // For navigation to Summary
    @State private var showTripSummary = false
    
    var totalSavings: Double {
        route?.stops.flatMap { $0.items }
            .filter { checkedItems.contains($0.id) }
            .reduce(0.0) { $0 + $1.savings } ?? 0.0
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Active Trip".localized)
                            .font(.headline)
                        // Broken down for compiler
                        let stopsText = "\(route?.stops.count ?? 0) " + "Stops".localized
                        let timeText = " • \(route?.estTime ?? "--")"
                        Text(stopsText + timeText)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    // Broken down for compiler
                    let amountText = String(format: "%.2f", Double(totalSavings))
                    let text = "\(amountText) ₼ " + "Savings".localized
                Text(text)
                        .font(.caption).bold()
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.1))
                        .clipShape(Capsule())
                    
                    // Mark All Button
                    Button(action: {
                        if let allItems = route?.stops.flatMap({ $0.items }) {
                            if checkedItems.count == allItems.count {
                                checkedItems.removeAll() // Toggle off if all selected? User said "mark all", usually implies select all.
                            } else {
                                checkedItems = Set(allItems.map { $0.id })
                            }
                        }
                    }) {
                        Image(systemName: "checklist.checked")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding()
                .background(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 5)
                .zIndex(1)
                
                if isLoading {
                    ProgressView().padding(.top, 50)
                    Spacer()
                } else if let stops = route?.stops {
                    ScrollView {
                        ZStack(alignment: .leading) {
                            // Connector Line
                            if stops.count > 1 {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 2)
                                    .padding(.top, 40)
                                    .padding(.bottom, 40)
                                    .padding(.leading, 35) // Approximate center of number badge
                            }
                            
                            VStack(spacing: 24) {
                                ForEach(stops) { stop in
                                    StopCard(stop: stop, checkedItems: $checkedItems, planId: planId)
                                }
                            }
                            .padding()
                        }
                    }
                } else {
                    Spacer()
                }
                
                // Footer
                let allItemsIds = route?.stops.flatMap { $0.items }.map { $0.id } ?? []
                let allItemsAreInitiallyChecked = !allItemsIds.isEmpty && initiallyCheckedItems.count == allItemsIds.count
                
                if !allItemsAreInitiallyChecked {
                    VStack {
                        // Removed NavigationLink to TripSummaryScreen
                    
                    Button(action: {
                        Task {
                            let newCheckedItems = checkedItems.subtracting(initiallyCheckedItems)
                            let checkedItemsCount = newCheckedItems.count
                            let newSavings = route?.stops.flatMap { $0.items }
                                .filter { newCheckedItems.contains($0.id) }
                                .reduce(0.0) { $0 + $1.savings } ?? 0.0
                                
                            let timeSpent = route?.estTime ?? "0 mins"
                            
                            // Only save stats if items were actually purchased
                            if checkedItemsCount > 0 {
                                do {
                                    try await APIService.shared.completeTrip(
                                        totalSavings: newSavings,
                                        timeSpent: timeSpent,
                                        dealsScouted: checkedItemsCount
                                    )
                                } catch {
                                    print("Failed to save trip: \(error)")
                                }
                            }
                            
                            if let pid = planId {
                                RouteCacheService.shared.completePlan(id: pid, checkedItems: checkedItems)
                            } else if checkedItemsCount == 0 && routeId == "active" {
                                if let pid = planId {
                                    RouteCacheService.shared.deletePlan(id: pid)
                                }
                            }
                            
                            // Return to PFM / Main screen
                            NotificationCenter.default.post(name: NSNotification.Name("SwitchToPFM"), object: nil)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("Complete Shopping Trip".localized)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.green)
                        .cornerRadius(16)
                        .shadow(color: .green.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                }
                .padding()
                .background(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: -5)
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // ... (rest of task logic unchanged)
            if let preloaded = preloadedRoute {
                self.route = preloaded
                self.isLoading = false
            } else {
                do {
                    route = try await APIService.shared.getRouteDetails(optionId: routeId)
                } catch {
                    print("Error loading active route: \(error)")
                }
                isLoading = false
            }
            
            // If viewing a Completed History plan (no active planId, but route loaded),
            // auto-check all items to show them as "Done".
            if routeId == "history" && planId == nil, let loadedRoute = self.route {
                let allIds = loadedRoute.stops.flatMap { $0.items }.map { $0.id }
                self.checkedItems = Set(allIds)
                self.initiallyCheckedItems = Set(allIds)
            } else if let loadedRoute = self.route {
                // If it's an active plan, load checked state from the items themselves
                let checkedIds = loadedRoute.stops.flatMap { $0.items }.filter { $0.checked }.map { $0.id }
                self.checkedItems = Set(checkedIds)
                self.initiallyCheckedItems = Set(checkedIds)
            }
        }
    } // Close body
    
    // Environment wrapper for dismissing
    @Environment(\.presentationMode) var presentationMode
}

struct StopCard: View {
    let stop: RouteStore
    @Binding var checkedItems: Set<String>
    var planId: String? // Added planId
    
    @EnvironmentObject var localization: LocalizationManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 12) {
                    Circle()
                        .fill(stop.color == "red" ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text("\(stop.sequence)")
                                .font(.headline)
                                .foregroundColor(stop.color == "red" ? .red : .blue)
                        )
                    
                    VStack(alignment: .leading) {
                        Text(stop.store).font(.headline)
                        
                        // Handle both old cached name and new name
                        if stop.store == "Other items" || stop.store == "Other Stores" {
                            let itemsText = "\(stop.items.count) " + "Items".localized
                            Text(itemsText)
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else {
                            // Broken down for compiler
                            let distanceText = "\(stop.distance) " + "away".localized
                            let itemsText = " • \(stop.items.count) " + "Items".localized
                            Text(distanceText + itemsText)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Spacer()
                
                Menu {
                    ForEach(MapService.shared.getAvailableApps()) { app in
                        Button(action: {
                            openMap(app: app, storeName: stop.store)
                        }) {
                            Label(app.localizedName, systemImage: "arrow.triangle.turn.up.right.circle")
                        }
                    }
                } label: {
                    Label("Navigate".localized, systemImage: "location.fill")
                    .font(.caption).bold()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                }
                .opacity(stop.store == "Other items" || stop.store == "Other Stores" ? 0 : 1) // Hide for generic stop
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            
            Divider()
            
            // Items
            VStack(spacing: 0) {
                ForEach(stop.items) { item in
                    VStack(spacing: 0) {
                        HStack(alignment: .top, spacing: 12) {
                            Button(action: {
                                var isNowChecked = false
                                if checkedItems.contains(item.id) {
                                    checkedItems.remove(item.id)
                                    isNowChecked = false
                                } else {
                                    checkedItems.insert(item.id)
                                    isNowChecked = true
                                }
                                
                                // Update Persistence
                                if let validPlanId = self.planId {
                                     RouteCacheService.shared.updateItemCheckState(planId: validPlanId, itemId: item.id, isChecked: isNowChecked)
                                }
                            }) {
                                Image(systemName: checkedItems.contains(item.id) ? "checkmark.square.fill" : "square")
                                    .font(.title3)
                                    .foregroundColor(checkedItems.contains(item.id) ? .green : .gray)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(checkedItems.contains(item.id) ? .gray : .primary)
                                    .strikethrough(checkedItems.contains(item.id))
                                
                                if stop.store == "Other items" || stop.store == "Other Stores" || item.price == 0 {
                                    Text(item.aisle == "General" ? "General".localized : item.aisle)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                } else {
                                    Text("\((item.aisle == "General" ? "General".localized : item.aisle)) • \(String(format: "%.2f", item.price)) ₼")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            
                            if stop.store != "Other items" && stop.store != "Other Stores" && item.savings > 0 {
                                Text("Save".localized + " \(String(format: "%.2f", item.savings)) ₼")
                                    .font(.caption).bold()
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        
                        if item.id != stop.items.last?.id {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }
        }
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    func openMap(app: MapApp, storeName: String) {
        Task {
            do {
                let stores = try await APIService.shared.getAvailableStores()
                if let match = stores.first(where: { $0.name == storeName }),
                   let lat = match.lat, let lon = match.lon {
                    await MainActor.run {
                         MapService.shared.openMap(app: app, lat: lat, lon: lon, name: storeName)
                    }
                } else {
                    await MainActor.run {
                        MapService.shared.searchMap(app: app, query: storeName)
                    }
                }
            } catch {
                print("Error finding store location: \(error)")
            }
        }
    }
}
