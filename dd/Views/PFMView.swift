import SwiftUI

struct PFMView: View {
    @ObservedObject var routeService = RouteCacheService.shared
    @EnvironmentObject var localization: LocalizationManager
    @State private var navigationSelection: String?
    @State private var activePlanId: String?
    @State private var selectedRouteItem: RouteHistoryItem?
    @State private var routeNavMode: String = "history"
    
    // Derived Active Route (Most Recent Active)
    private var featuredActivePlan: RouteHistoryItem? {
        routeService.history.first(where: { $0.status == "active" })
    }
    
    // Derived Recent History (Top 3 of ALL plans, including active ones if recent)
    // User requested: "make sure you add all plans to recent history doesnt mayter it is in progress or complete"
    private var recentHistory: [RouteHistoryItem] {
        Array(routeService.history.prefix(3))
    }
    
    // Derived Stats
    private var totalSavedLifetime: Double {
        routeService.history
            .filter { $0.status == "completed" }
            .map { $0.route.totalSavings }
            .reduce(0, +)
    }
    
    private var completedTripsCount: Int {
        routeService.history.filter { $0.status == "completed" }.count
    }
    
    var body: some View {
        NavigationView {
             VStack(spacing: 0) {
                 // Header
                 HStack {
                     Text("My Plans".localized)
                         .font(.title).bold()
                     Spacer()
                 }
                 .padding()
                 .background(Color.white)
                 
                 ScrollView {
                     // Hidden Navigation Link for programmatic route navigation
                     NavigationLink(
                         destination: selectedRouteDestination,
                         tag: "route",
                         selection: $navigationSelection
                     ) {
                         EmptyView()
                     }
                     
                     // Hidden Navigation Link for View All History
                     NavigationLink(
                         destination: PlanHistoryScreen(),
                         tag: "history",
                         selection: $navigationSelection
                     ) {
                         EmptyView()
                     }
                     
                     VStack(spacing: 10) { // Reduced spacing from 16 to 10
                         
                        // 1. ACTIVE PLAN (Most Recent Active)
                        if let item = featuredActivePlan {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 48, height: 48)
                                        
                                        Image(systemName: "cart.fill")
                                            .foregroundColor(.white)
                                            .font(.system(size: 20))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Current Focus".localized)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .textCase(.uppercase)
                                        
                                        Text("Active Shopping Plan".localized)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                            
                                        Text("\(item.route.stops.count) \("Stores".localized) • \(item.route.estTime.replacingOccurrences(of: "mins", with: "min".localized).replacingOccurrences(of: "min", with: "min".localized))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    
                                    // Savings Badge
                                    let savings = item.status == "completed"
                                        ? item.route.stops.flatMap { $0.items }.filter { $0.checked }.reduce(0.0) { $0 + $1.savings }
                                        : item.route.stops.flatMap { $0.items }.reduce(0.0) { $0 + $1.savings }
                                    VStack(alignment: .trailing) {
                                        Text("\("Save".localized) \(String(format: "%.2f", savings)) ₼")
                                            .font(.headline)
                                            .fixedSize(horizontal: true, vertical: false) // Prevent truncation
                                            .foregroundColor(.green)
                                        Text("Estimated".localized)
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(8)
                                    .layoutPriority(1) // Ensure it doesn't get squished
                                }
                                
                                Divider()
                                
                                Button(action: {
                                    selectedRouteItem = item
                                    routeNavMode = "cached"
                                    navigationSelection = "route"
                                }) {
                                    HStack {
                                        Text("Continue Shopping".localized)
                                            .font(.subheadline)
                                            .bold()
                                        Spacer()
                                        Image(systemName: "arrow.right.circle.fill")
                                            .font(.title3)
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(12)
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
                        }
                        
                        // 2. COMPACT STATS SUMMARY
                        // Redesigned: Total on top, Trips/Scouted below
                        VStack(spacing: 0) {
                            // Top: Total Saved
                            VStack(spacing: 4) {
                                // Use BACKEND calculated stats
                                Text("\(String(format: "%.2f", routeService.lifetimeStats.totalSavings)) ₼")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.green)
                                Text("Total Saved".localized)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .textCase(.uppercase)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            
                            Divider()
                            
                            // Bottom: Trips & Scouted
                            HStack(spacing: 0) {
                                // Trips
                                VStack(spacing: 4) {
                                    Text("\(routeService.lifetimeStats.totalTrips)")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("Trips".localized)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                        .textCase(.uppercase)
                                }
                                .frame(maxWidth: .infinity)
                                
                                Divider().frame(height: 25)
                                
                                // Scouted
                                VStack(spacing: 4) {
                                    Text("\(routeService.lifetimeStats.totalTrips * 12)") // Mock approximation for now
                                        .font(.headline)
                                        .foregroundColor(.purple)
                                    Text("Deals Scouted".localized)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                        .textCase(.uppercase)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.vertical, 10)
                            .background(Color.gray.opacity(0.02))
                        }
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        
                        // 3. HISTORY
                        if !recentHistory.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Recent History".localized)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Button(action: {
                                        navigationSelection = "history"
                                    }) {
                                        Text("View All".localized)
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal, 4)
                                                                ForEach(recentHistory) { item in
                                    HistoryCard(item: item) { clickedItem in
                                        selectedRouteItem = clickedItem
                                        routeNavMode = "history"
                                        navigationSelection = "route"
                                    }
                                 }
                            }
                        }
                     }
                     .padding()
                 }
                 .background(Color(UIColor.systemGroupedBackground))
             }
             .onAppear {
                 routeService.refreshHistory()
                 
                 // If we came back from a completed trip, ensure navigation is unlocked
                 navigationSelection = nil
             }
             .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToPFM"))) { _ in
                 routeService.refreshHistory()
                 
                 // Auto-navigate to Active Trip if available
                 // We add a small delay to ensure TabView switch completes first
                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                     if let active = featuredActivePlan {
                         self.activePlanId = active.id
                         self.selectedRouteItem = active
                         self.routeNavMode = "cached"
                         self.navigationSelection = "route"
                     }
                 }
             }
        }
    }
    
    // Removed old loadData()
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private var selectedRouteDestination: some View {
        if let item = selectedRouteItem {
            let mode = routeNavMode
            let pId: String? = item.id
            return AnyView(ActiveRouteScreen(routeId: mode, preloadedRoute: item.route, planId: pId))
        } else {
            return AnyView(Text("Loading..."))
        }
    }
}

struct HistoryCard: View {
    let item: RouteHistoryItem
    var onTap: (RouteHistoryItem) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(formatDate(item.date))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                if item.status == "completed" {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Completed".localized)
                    }
                    .font(.caption).bold()
                    .foregroundColor(.green)
                } else if item.status == "active" {
                    HStack(spacing: 4) {
                        Image(systemName: "cart.circle.fill")
                        Text("In Progress".localized)
                    }
                    .font(.caption).bold()
                    .foregroundColor(.blue)
                } else {
                    Text(item.status.capitalized)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("\(item.route.stops.count) \("Stores".localized)")
                        .font(.headline)
                    Text(item.route.estTime.replacingOccurrences(of: "mins", with: "min".localized).replacingOccurrences(of: "min", with: "min".localized))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    let savings = item.status == "completed"
                        ? item.route.stops.flatMap { $0.items }.filter { $0.checked }.reduce(0.0) { $0 + $1.savings }
                        : item.route.stops.flatMap { $0.items }.reduce(0.0) { $0 + $1.savings }
                    Text("\("Saved".localized) \(String(format: "%.2f", Double(savings))) ₼")
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }
            
            // Link to view details just in case?
            // For now just read-only history summary
            // Link with hidden chevron workaround
            Button(action: {
                onTap(item)
            }) {
                Text(item.status == "active" ? "Continue Shopping".localized : "View Summary".localized)
                    .font(.caption).bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(item.status == "active" ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .foregroundColor(item.status == "active" ? .blue : .blue)
                    .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter.string(from: date)
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .cornerRadius(10)
            
            VStack(alignment: .leading) {
                Text(title.localized)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
