import SwiftUI

struct ActiveRouteScreen: View {
    let routeId: String
    var preloadedRoute: RouteDetails? = nil // Optional preloaded data
    var planId: String? = nil // Optional Plan ID if this is a saved plan
    
    @State private var route: RouteDetails?
    @State private var isLoading = true
    @State private var checkedItems: Set<String> = []
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
                                    StopCard(stop: stop, checkedItems: $checkedItems)
                                }
                            }
                            .padding()
                        }
                    }
                } else {
                    Spacer()
                }
                
                // Footer
                VStack {
                    // Removed NavigationLink to TripSummaryScreen
                    
                    Button(action: {
                        Task {
                            let checkedItemsCount = checkedItems.count
                            let timeSpent = route?.estTime ?? "0 mins"
                            
                            // Only save stats if items were actually purchased
                            if checkedItemsCount > 0 {
                                do {
                                    try await APIService.shared.completeTrip(
                                        totalSavings: totalSavings,
                                        timeSpent: timeSpent,
                                        dealsScouted: checkedItemsCount
                                    )
                                } catch {
                                    print("Failed to save trip: \(error)")
                                }
                                
                                // Mark as completed in PFM history
                                if let pid = planId {
                                    RouteCacheService.shared.completePlan(id: pid, checkedItems: checkedItems)
                                }
                            } else {
                                // If 0 items checked, DISCARD the trip completely (don't save to history)
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
            }
    }
    } // Close body
    
    // Environment wrapper for dismissing
    @Environment(\.presentationMode) var presentationMode
}

struct StopCard: View {
    let stop: RouteStore
    @Binding var checkedItems: Set<String>
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
                        
                        // Broken down for compiler
                        let distanceText = "\(stop.distance) " + "away".localized
                        let itemsText = " • \(stop.items.count) " + "Items".localized
                        Text(distanceText + itemsText)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    openGoogleMaps(for: stop.store)
                }) {
                    Label("Navigate".localized, systemImage: "location.fill")
                        .font(.caption).bold()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                }
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
                                if checkedItems.contains(item.id) {
                                    checkedItems.remove(item.id)
                                } else {
                                    checkedItems.insert(item.id)
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
                                
                                Text("\(item.aisle) • \(String(format: "%.2f", item.price)) ₼")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Text("Save".localized + " \(String(format: "%.2f", item.savings)) ₼")
                                .font(.caption).bold()
                                .foregroundColor(.green)
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
    
    func openGoogleMaps(for storeName: String) {
        Task {
            do {
                let stores = try await APIService.shared.getAvailableStores()
                if let match = stores.first(where: { $0.name == storeName }),
                   let lat = match.lat, let lon = match.lon {
                    
                    let urlStr = "comgooglemaps://?daddr=\(lat),\(lon)&directionsmode=driving"
                    if let url = URL(string: urlStr), UIApplication.shared.canOpenURL(url) {
                        await UIApplication.shared.open(url)
                    } else {
                        let browserUrl = "https://www.google.com/maps/dir/?api=1&destination=\(lat),\(lon)"
                        if let url = URL(string: browserUrl) {
                            await UIApplication.shared.open(url)
                        }
                    }
                } else {
                    let query = storeName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    let urlStr = "comgooglemaps://?q=\(query)"
                    if let url = URL(string: urlStr), UIApplication.shared.canOpenURL(url) {
                        await UIApplication.shared.open(url)
                    } else {
                         let browserUrl = "https://www.google.com/maps/search/?api=1&query=\(query)"
                         if let url = URL(string: browserUrl) {
                             await UIApplication.shared.open(url)
                         }
                    }
                }
            } catch {
                print("Error finding store location: \(error)")
            }
        }
    }
}
