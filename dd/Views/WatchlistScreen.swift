import SwiftUI

struct WatchlistScreen: View {
    @State private var response: WatchlistResponse?
    @State private var isLoading = true
    @EnvironmentObject var localization: LocalizationManager
    
    var body: some View {
        NavigationView {
             VStack {
                 if isLoading {
                     ProgressView()
                 } else if let items = response?.items, !items.isEmpty {
                     List {
                         Section(header: Text("Saved Items".localized)) {
                             ForEach(items) { item in
                                 WatchlistItemRow(item: item)
                             }
                         }
                         
                         if let popular = response?.popularEssentials, !popular.isEmpty {
                             Section(header: Text("Popular Essentials".localized)) {
                                 ScrollView(.horizontal, showsIndicators: false) {
                                     HStack {
                                         ForEach(popular, id: \.self) { name in
                                             Text(name) // name is dynamic
                                                 .padding(.horizontal, 16)
                                                 .padding(.vertical, 8)
                                                 .background(Color.blue.opacity(0.1))
                                                 .foregroundColor(.blue)
                                                 .cornerRadius(20)
                                         }
                                     }
                                     .padding(.vertical, 8)
                                 }
                             }
                         }
                     }
                 } else {
                     VStack {
                         Image(systemName: "eye.slash")
                             .font(.largeTitle)
                             .foregroundColor(.gray)
                             .padding()
                         Text("Your watchlist is empty".localized)
                             .foregroundColor(.gray)
                     }
                 }
             }
             .navigationTitle("Watchlist".localized)
             .task {
                 do {
                     response = try await APIService.shared.getWatchlist()
                 } catch {
                     print("Error loading watchlist: \(error)")
                 }
                 isLoading = false
             }
        }
    }
}

struct WatchlistItemRow: View {
    let item: WatchlistItem
    
    var body: some View {
        HStack {
            Image(systemName: item.iconType)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading) {
                Text(item.name).font(.headline)
                Text(item.subtitle).font(.caption).foregroundColor(.gray)
            }
            
            Spacer()
            
            if let badge = item.badge {
                 Text(badge)
                    .font(.caption).bold()
                    .padding(6)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            Text(item.status)
                .font(.subheadline)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }
}
