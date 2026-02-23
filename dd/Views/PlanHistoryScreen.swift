import SwiftUI

struct PlanHistoryScreen: View {
    @ObservedObject var routeService = RouteCacheService.shared
    @State private var selectedItem: RouteHistoryItem?
    @State private var navigateToDetails = false
    
    var body: some View {
        ZStack {
            // Hidden Link for safe navigation
            NavigationLink(
                destination: selectedDestination,
                isActive: $navigateToDetails
            ) { EmptyView() }
            
            List {
            // Section for spacing if needed or just plain list
            if routeService.history.isEmpty {
                 VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No past plans yet".localized)
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 40)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(routeService.history) { item in
                    HistoryCard(item: item) { clickedItem in
                        selectedItem = clickedItem
                        navigateToDetails = true
                    }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)) // Custom padding
                }
                .onDelete { indexSet in
                    for index in indexSet {
                         let item = routeService.history[index]
                         RouteCacheService.shared.deletePlan(id: item.id)
                    }
                }
            }
        }
        }
        .listStyle(.plain)
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Shopping History".localized)
        .onAppear {
            routeService.refreshHistory()
            navigateToDetails = false
        }
    }
    
    // Extracted destination view
    private var selectedDestination: some View {
        if let item = selectedItem {
            return AnyView(ActiveRouteScreen(routeId: "history", preloadedRoute: item.route, planId: item.status == "active" ? item.id : nil))
        } else {
            return AnyView(EmptyView())
        }
    }
}
