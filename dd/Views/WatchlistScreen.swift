import SwiftUI

struct WatchlistScreen: View {
    @State private var response: WatchlistResponse?
    @State private var isLoading = true
    @State private var searchQuery = ""
    @State private var searchResults: [Product] = [] // Raw results (unused for suggestions)
    @State private var suggestions: [String] = []
    @State private var isSearching = false
    
    // Navigation State
    @State private var navigateToBrandSelection = false
    @State private var selectedBrandGroup: [BrandGroup] = []
    @State private var isAddingToPlan = false
    @State private var editMode: EditMode = .inactive
    
    @ObservedObject private var watchlistService = LocalWatchlistService.shared
    @EnvironmentObject var localization: LocalizationManager
    
    var body: some View {
        NavigationView {
             VStack(spacing: 0) {
                 // Search Input
                 VStack {
                     HStack {
                         Image(systemName: "magnifyingglass")
                             .foregroundColor(.gray)
                         TextField("Add item (e.g. Diapers)...".localized, text: $searchQuery)
                             .onSubmit {
                                 if !searchQuery.isEmpty {
                                     watchlistService.saveItem(name: searchQuery)
                                     searchQuery = ""
                                     suggestions = []
                                     isSearching = false
                                 }
                             }
                         if !searchQuery.isEmpty {
                             Button("Add".localized) {
                                 watchlistService.saveItem(name: searchQuery)
                                 searchQuery = "" // Clear
                                 suggestions = []
                                 isSearching = false
                             }
                             .font(.caption).bold()
                             .padding(.horizontal, 12)
                             .padding(.vertical, 6)
                             .background(Color.black)
                             .foregroundColor(.white)
                             .cornerRadius(8)
                         }
                     }
                     .padding()
                     .background(Color(.systemGray6))
                     .cornerRadius(12)
                     .padding(.horizontal)
                     .padding(.top)
                 }
                 
                 // Navigation Link (Hidden)
                 NavigationLink(isActive: $navigateToBrandSelection) {
                     BrandSelectionScreen(
                         scanId: nil,
                         preloadedGroups: selectedBrandGroup,
                         onCommit: { selectedIds in
                             addToPlan(ids: selectedIds)
                         }
                     )
                 } label: {
                     EmptyView()
                 }
                 
                 if !searchQuery.isEmpty {
                     // SEARCH SUGGESTIONS VIEW
                     if isSearching {
                         ProgressView()
                             .frame(maxWidth: .infinity, maxHeight: .infinity)
                     } else if suggestions.isEmpty {
                         VStack {
                             Image(systemName: "magnifyingglass")
                                 .font(.largeTitle)
                                 .foregroundColor(.gray)
                                 .padding()
                             Text("\("No suggestions for".localized) '\(searchQuery)'")
                                 .foregroundColor(.gray)
                         }
                         .frame(maxWidth: .infinity, maxHeight: .infinity)
                     } else {
                         List {
                             ForEach(suggestions.prefix(5), id: \.self) { suggestion in
                                 Button(action: {
                                     searchQuery = suggestion
                                     // Do not add immediately, user must press Add or Enter
                                 }) {
                                     HStack {
                                         Image(systemName: "magnifyingglass")
                                             .foregroundColor(.gray)
                                         Text(suggestion)
                                             .foregroundColor(.primary)
                                         Spacer()
                                         Image(systemName: "arrow.up.left") // Indicate copying to text
                                             .foregroundColor(.gray)
                                     }
                                 }
                             }
                         }
                         .listStyle(PlainListStyle())
                     }
                 } else {
                     // WATCHLIST VIEW
                     if isLoading {
                         VStack {
                             Spacer()
                             ProgressView()
                             Spacer()
                         }
                         .frame(maxWidth: .infinity, maxHeight: .infinity)
                     } else {
                         List {
                             // Combine Local + API Items
                             let allItems = watchlistService.savedItems + (response?.items ?? [])
                             
                             if !allItems.isEmpty {
                                 ForEach(allItems) { item in
                                     WatchlistItemRow(item: item)
                                         .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                         .listRowSeparator(.hidden)
                                         .listRowBackground(Color.clear)
                                         .onTapGesture {
                                             Task {
                                                 await searchAndOpen(query: item.name)
                                             }
                                         }
                                 }
                                 .onDelete { indexSet in
                                     indexSet.forEach { index in
                                         let item = allItems[index]
                                         watchlistService.removeItem(item.id)
                                     }
                                 }
                             }
                             
                             if allItems.isEmpty {
                                 VStack {
                                     Image(systemName: "eye.slash")
                                         .font(.largeTitle)
                                         .foregroundColor(.gray)
                                         .padding()
                                     Text("Your watchlist is empty".localized)
                                         .foregroundColor(.gray)
                                     Text("Search above to track prices.".localized)
                                         .font(.caption)
                                         .foregroundColor(.gray)
                                 }
                                 .frame(maxWidth: .infinity, alignment: .center)
                                 .listRowBackground(Color.clear)
                                 .padding(.top, 50)
                             }
                         }
                         .listStyle(PlainListStyle())
                     }
                 }
             }
             .navigationBarTitle("My Watchlist".localized, displayMode: .automatic)
             .navigationBarTitle("My Watchlist".localized, displayMode: .automatic)
             .toolbar {
                 ToolbarItem(placement: .navigationBarTrailing) {
                     Button {
                         withAnimation {
                             editMode = editMode == .active ? .inactive : .active
                         }
                     } label: {
                         Text(editMode == .active ? "Done".localized : "Edit".localized)
                             .foregroundColor(Color(hex: "059669"))
                     }
                 }
             }
             .environment(\.editMode, $editMode)
             .task {
                 do {
                     response = try await APIService.shared.getWatchlist()
                     await refreshWatchlistData()
                 } catch {
                     print("Error loading watchlist: \(error)")
                 }
                 isLoading = false
             }
             .onChange(of: searchQuery) { query in
                 Task {
                     if query.count >= 2 {
                         isSearching = true
                         try? await Task.sleep(nanoseconds: 300_000_000)
                         if query == searchQuery {
                             do {
                                 suggestions = try await APIService.shared.searchKeywords(query: query)
                             } catch {
                                 print("Search error: \(error)")
                                 suggestions = []
                             }
                             isSearching = false
                         }
                     } else {
                         suggestions = []
                         isSearching = false
                     }
                 }
             }
             // Overlay Spinner for Plan Add
             .overlay(
                 isAddingToPlan ? 
                 ZStack {
                     Color.black.opacity(0.3).ignoresSafeArea()
                     ProgressView("Adding to list...".localized)
                     .padding()
                     .background(Color.white)
                     .cornerRadius(10)
                 } : nil
             )
        }
    }
    
    // Cache for Scan Flow results
    @State private var scanFlowGroups: [BrandGroup] = []

    func refreshWatchlistData() async {
        let savedItems = watchlistService.savedItems
        if savedItems.isEmpty { return }
        
        // SCAN FLOW SIMULATION
        // 1. Create DetectedItems from Watchlist
        let scanItems = savedItems.map { item in
            DetectedItem(
                id: UUID().uuidString,
                name: item.name,
                confidence: 1.0,
                boundingBox: nil,
                dealAvailable: true,
                imageUrl: nil
            )
        }
        
        let scanId = UUID().uuidString
        
        do {
            // 2. Confirm Scan (Send to backend)
            _ = try await APIService.shared.confirmScan(scanId: scanId, items: scanItems)
            
            // 3. Get Brands (Unlimited/Optimized search)
            let brandResponse = try await APIService.shared.getBrands(scanId: scanId)
            let groups = brandResponse.groups ?? []
            
            await MainActor.run {
                self.scanFlowGroups = groups
                
                // 4. Update Local Item Statuses
                for item in savedItems {
                    // Find matching group
                    if let group = groups.first(where: {
                        $0.itemName.caseInsensitiveCompare(item.name) == .orderedSame ||
                        $0.itemName.localizedCaseInsensitiveContains(item.name) ||
                        item.name.localizedCaseInsensitiveContains($0.itemName)
                    }) {
                         let count = group.options.count
                         let maxDiscount = group.options.compactMap {
                             Int($0.badge?.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "%", with: "") ?? "0")
                         }.max() ?? 0
                         
                         let minPrice = group.options.compactMap { $0.price }.min() ?? 0
                         
                         watchlistService.updateItemStatus(
                             id: item.id,
                             status: "\(count) \("Deals Found".localized)",
                             subtitle: "From \(String(format: "%.2f", minPrice)) ₼",
                             badge: maxDiscount > 0 ? "-\(maxDiscount)%" : nil
                         )
                    } else {
                        watchlistService.updateItemStatus(
                            id: item.id,
                            status: "No active deals".localized,
                            subtitle: "Watching prices...".localized,
                            badge: nil
                        )
                    }
                }
            }
        } catch {
            print("Scan flow error: \(error)")
        }
    }
    
    // Helper to open BrandSelection
    func openSelection(for products: [Product]) {
        // Legacy/Fallback helper if needed, but we prefer openGroup
         let first = products.first!
         let options = products.map { p in
             BrandItem(
                 id: p.id,
                 brandName: p.name,
                 logoUrl: p.imageUrl,
                 dealText: "at \(p.store ?? "Generic Store")",
                 savings: (p.originalPrice ?? 0) - p.price,
                 isSelected: false,
                 price: p.price,
                 originalPrice: p.originalPrice,
                 badge: p.discountPercent != nil ? "-\(p.discountPercent!)%" : nil,
                 distance: nil,
                 estTime: nil
             )
         }
         
         let group = BrandGroup(
             itemName: first.name,
             itemDetails: "\(products.count) offers found",
             status: "DEAL_FOUND",
             options: options
         )
         
         self.selectedBrandGroup = [group]
         self.navigateToBrandSelection = true
    }
    
    func openGroup(_ group: BrandGroup) {
        self.selectedBrandGroup = [group]
        self.navigateToBrandSelection = true
    }
    
    func searchAndOpen(query: String) async {
        // Use cached group if available
        if let group = scanFlowGroups.first(where: {
            $0.itemName.caseInsensitiveCompare(query) == .orderedSame ||
            $0.itemName.localizedCaseInsensitiveContains(query) ||
            query.localizedCaseInsensitiveContains($0.itemName)
        }) {
             await MainActor.run {
                 openGroup(group)
             }
             return
        }
        
        // Fallback: If not in cache (e.g. freshly added or error), try legacy search
        isAddingToPlan = true
        do {
             let (products, _) = try await APIService.shared.searchProducts(query: query)
             if !products.isEmpty {
                 await MainActor.run {
                     isAddingToPlan = false
                     openSelection(for: products)
                 }
             } else {
                 await MainActor.run {
                     isAddingToPlan = false
                 }
             }
        } catch {
            await MainActor.run {
                isAddingToPlan = false
            }
        }
    }
    
    func addToPlan(ids: [String]) {
        // Here we need to find the full Product objects for these IDs?
        // Or does APIService support adding by ID?
        // `addItemToActivePlan` takes `Product`.
        // We have the products in `searchResults` (or potentially `response`?).
        // If we came from Search, we have them.
        // If we came from Watchlist -> Search, we have them from `searchAndOpen`.
        // But `selectedBrandGroup` has `BrandItem`s which have IDs.
        
        // We need to efficiently find the product to add.
        // Or update API to add by ID.
        // Assuming `APIService` mostly needs ID.
        // Let's check `addItemToActivePlan`.
        
        isAddingToPlan = true
        Task {
            // Simulate for now or implement batch add if API supports
            // The user only selects 1 usually (radio), but `selectedIds` is array.
            // Loop add
            // Find products in search results
            // Note: If we navigated from "Saved Items", searchResults might be empty or different.
            // We should ideally pass the `[Product]` to the `BrandSelectionScreen` or callbacks.
            // But `BrandSelectionScreen` only passes back `ids`.
            // We can search locally in `searchResults` first.
            // Or we assume `searchResults` contains the items because we call `searchAndOpen` which populates `products` (but doesn't set `searchResults` state).
            // Fix: We should update `searchResults` when we do `searchAndOpen` or store a separate `activeSelectionProducts` state.
            // Since `groupedSearchResults` is derived from `searchResults`, if we update `searchResults`, the UI behind might change (flickering).
            // Better: Just use `APIService` to fetch product by ID? No endpoint for that.
            
            // Hack: We can just use the info we have.
            // `BrandItem` has almost everything to reconstruct a simplified `Product`.
            // Missing `category` and `inStock`.
            // Let's rely on reconstruction from `selectedBrandGroup`.
            
            for id in ids {
                // We need to reconstruct Product or find it
                // `BrandItem` has price etc.
                if let group = selectedBrandGroup.first,
                   let option = group.options.first(where: { $0.id == id }) {
                    
                    let product = Product(
                        id: option.id,
                        name: option.brandName,
                        brand: nil,
                        category: nil, // Missing
                        store: nil, // Missing in BrandItem, partially in dealText
                        imageUrl: option.logoUrl,
                        price: option.price ?? 0,
                        originalPrice: option.originalPrice,
                        discountPercent: nil,
                        badge: option.badge,
                        inStock: true // Assume
                    )
                    
                    try? await APIService.shared.addItemToActivePlan(product: product)
                }
            }
            await RouteCacheService.shared.refreshHistory()
            isAddingToPlan = false
            navigateToBrandSelection = false // Pop back
        }
    }
}

// Custom Row for Search Results (Matching HTML "Deal Found" style)


// Helpers
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}




struct WatchlistItemRow: View {
    let item: WatchlistItem
    
    var isDealFound: Bool {
        // Robust check: If badge is present (discount) or status contains localized "Found"/"Tapıldı"
        // Better: Check if badge is not nil, as deals usually have a badge. 
        // Or check against known localized strings for "Deals Found"
        return item.badge != nil || item.status.contains("Found") || item.status.contains("Tapıldı")
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isDealFound ? Color(hex: "D1FAE5") : Color.gray.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: item.iconType)
                        .foregroundColor(isDealFound ? Color(hex: "059669") : .gray)
                        .font(.system(size: 20))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(hex: "111827"))
                    
                    HStack(spacing: 4) {
                        if isDealFound {
                            Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                        } else {
                            // Pulsing dot or just generic
                        }
                        
                        Text(item.status) // "X Deals Found" or "Watching prices..."
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isDealFound ? Color(hex: "059669") : .gray)
                    }
                }
                
                Spacer()
                
                if let badge = item.badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(hex: "BE123C"))
                        .clipShape(Capsule())
                } else if !isDealFound {
                    // Spinner logic could go here if loading, but item.status is static until update
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isDealFound ? Color(hex: "D1FAE5") : Color.gray.opacity(0.2), lineWidth: 1)
            )
            
            // Left Green Bar for Deals
            if isDealFound {
                Rectangle()
                    .fill(Color(hex: "059669"))
                    .frame(width: 4)
                    .cornerRadius(2, corners: [.topLeft, .bottomLeft])
                    .padding(.vertical, 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}
