import SwiftUI

struct PlanHistoryScreen: View {
    @ObservedObject var routeService = RouteCacheService.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Show all plans including active/in-progress
                let history = routeService.history
                
                if history.isEmpty {
                     VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No past plans yet".localized)
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(history) { item in
                        HistoryCard(item: item)
                    }
                }
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Shopping History".localized)
        .onAppear {
            routeService.refreshHistory()
        }
    }
}
