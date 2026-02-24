import SwiftUI

struct HomeScreen: View {
    @State private var homeFeed: HomeFeedResponse?
    @State private var products: [Product] = [] // Separate products to support appending
    @State private var searchQuery = ""
    @State private var searchResults: [Product] = []
    @State private var errorMessage: String?
    @State private var showError = false
    
    // Pagination State
    @State private var currentPage = 1
    @State private var isLoading = false
    @State private var canLoadMore = true
    @State private var isSearching = false // Track search loading state
    
    // Sort & Filter State
    @State private var selectedSort: SortOption = .discountPct
    @State private var selectedStore: String? = nil
    
    // Fetched dynamically
    @State private var availableStores: [String] = []
    
    enum SortOption: String, CaseIterable, Identifiable {
        case discountPct = "discount_pct"
        case priceAsc = "price_asc"
        case priceDesc = "price_desc"
        case discountVal = "discount_val"
        case marketName = "market_name"
        
        var id: String { self.rawValue }
        
        var displayName: String {
            switch self {
            case .discountPct: return "Best Discount".localized
            case .priceAsc: return "Price: Low to High".localized
            case .priceDesc: return "Price: High to Low".localized
            case .discountVal: return "Max Savings".localized
            case .marketName: return "Store Name".localized
            }
        }
    }
    @EnvironmentObject var localization: LocalizationManager
    
    @ObservedObject private var locationManager = LocationManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Custom Header with Settings Button
                    HStack(spacing: 12) {
                        Image("HeaderLogo")
                            .resizable()
                            .renderingMode(.original)
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                        Text("Daily Deals".localized)
                            .font(.largeTitle)
                            .bold()
                        
                        Spacer()
                        
                        NavigationLink(destination: ProfileScreen()
                            .environmentObject(localization)) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    // Search Bar - always show
                    SearchBar(text: $searchQuery)
                        .padding(.horizontal, 20)
                    
                    // Check if searching
                    if !searchQuery.isEmpty {
                        // SEARCH MODE - independent of home feed
                        if searchResults.isEmpty {
                            if searchQuery.count >= 2 {
                                if isSearching {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, 50)
                                } else {
                                    Text("No items found".localized)
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, 50)
                                }
                            }
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(searchResults) { product in
                                    NavigationLink(destination: ProductDetailScreen(product: product)) {
                                        ProductCard(product: product)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    } else if let feed = homeFeed {
                        // HOME FEED MODE
                        VStack(alignment: .leading, spacing: 8) { // Reduced from 16 to 8
                            // Sort & Filter Bar (Wraps to new line if text is too long)
                            ViewThatFits(in: .horizontal) {
                                HStack {
                                    SortMenuContent(selectedSort: $selectedSort, passAction: loadFeed)
                                    FilterMenuContent(selectedStore: $selectedStore, availableStores: availableStores, passAction: loadFeed)
                                }
                                VStack(alignment: .leading, spacing: 12) {
                                    SortMenuContent(selectedSort: $selectedSort, passAction: loadFeed)
                                    FilterMenuContent(selectedStore: $selectedStore, availableStores: availableStores, passAction: loadFeed)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Standard Home Feed
                        
                        // Hero Section
                            if let hero = feed.hero {
                                NavigationLink(destination: ProductDetailScreen(product: hero.product)) {
                                    HeroSection(hero: hero)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // Categories removed per user request
                            
                            // Product Grid
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                ForEach(products) { product in
                                    NavigationLink(destination: ProductDetailScreen(product: product)) {
                                        ProductCard(product: product)
                                            .onAppear {
                                                if product.id == products.last?.id {
                                                    loadMore()
                                                }
                                            }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            
                            // Bottom Loader
                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                        
                    } else {
                        ProgressView("Loading...".localized)
                            .frame(maxWidth: .infinity, minHeight: 200)
                            .padding(.horizontal, 20)
                    }
                }
                .frame(maxWidth: .infinity)
                // .padding(.vertical)
            }

            .navigationTitle("Daily Deals".localized)
            .navigationBarHidden(true)
            .task {
                await loadStores()
                await loadFeed(reload: true)
            }
            .task(id: searchQuery) {
                if searchQuery.count >= 2 {
                    isSearching = true
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s debounce
                    if Task.isCancelled { return }
                    do {
                        let (results, _) = try await APIService.shared.searchProducts(query: searchQuery)
                        searchResults = results
                    } catch {
                        print("Search error: \(error)")
                    }
                    isSearching = false
                } else {
                    searchResults = []
                    isSearching = false
                }
            }
            .alert(isPresented: $showError) {
                Alert(title: Text("Error"), message: Text(errorMessage ?? "Unknown error"), dismissButton: .default(Text("OK"), action: {
                    Task { await loadFeed(reload: true) }
                }))
            }
            .onChange(of: locationManager.location) { _ in
                Task {
                    await loadStores()
                    await loadFeed(reload: true)
                }
            }
            .onChange(of: locationManager.searchRangeKm) { _ in
                Task {
                    await loadStores()
                    await loadFeed(reload: true)
                }
            }
        }
    }
    
    func loadStores() async {
        do {
            let stores = try await APIService.shared.getAvailableStores()
            // Map to names and sort
            availableStores = stores.map { $0.name }.sorted()
        } catch {
            print("Failed to load stores: \(error)")
        }
    }
    
    func loadFeed(reload: Bool = false) async {
        guard !isLoading else { return }
        
        if reload {
            currentPage = 1
            canLoadMore = true
            // Don't clear products immediately to avoid flicker if just refreshing, 
            // but for first load it's fine.
        }
        
        guard canLoadMore else { return }
        
        isLoading = true
        do {
            let response = try await APIService.shared.getHomeFeed(
                page: currentPage, 
                limit: 20, 
                sortBy: selectedSort.rawValue, 
                storeFilter: selectedStore
            )
            
            if reload {
                homeFeed = response
                products = response.products
            } else {
                // Append separate products
                products.append(contentsOf: response.products)
            }
            
            // If no products returned, we reached the end
            if response.products.isEmpty {
                canLoadMore = false
            } else {
                currentPage += 1
            }
            
            isLoading = false
        } catch {
            if (error as? URLError)?.code == .cancelled || (error as NSError).code == NSURLErrorCancelled { return }
            if case APIError.cancelled = error { return }
            isLoading = false
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func loadMore() {
        Task {
            await loadFeed(reload: false)
        }
    }
}

// MARK: - Subviews



struct HeroSection: View {
    let hero: Hero
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(hero.title)
                    .font(.title2)
                    .bold()
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Text(hero.subtitle)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            ZStack(alignment: .bottomLeading) {
                Color.clear
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 200, maxHeight: 200)
                    .overlay(
                        AsyncImage(url: URL(string: hero.product.imageUrl)) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                Color.gray.opacity(0.3)
                            }
                        }
                    )
                    .clipped()
                    .cornerRadius(16)
                
                if let discount = hero.product.discountPercent, discount > 0 {
                    Text(String(format: "off_percent_format".localized, discount))
                        .font(.caption).bold()
                        .padding(6)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .padding(12)
                } else if let badge = hero.product.badge {
                    Text(badge.localized)
                        .font(.caption).bold()
                        .padding(6)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .padding(12)
                }
            }
            
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text(hero.product.brand ?? "")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(hero.product.name)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 10)
                VStack(alignment: .trailing) {
                    Text("\(String(format: "%.2f", hero.product.price)) ₼")
                        .font(.title3).bold().foregroundColor(.blue)
                    if let original = hero.product.originalPrice {
                        Text("\(String(format: "%.2f", original)) ₼")
                            .font(.caption).strikethrough().foregroundColor(.gray)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct CategoryPill: View {
    let category: Category
    
    var body: some View {
        Text(category.name)
            .font(.subheadline).bold()
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(category.selected == true ? Color.black : Color.white)
            .foregroundColor(category.selected == true ? .white : .black)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}

struct SortMenuContent: View {
    @Binding var selectedSort: HomeScreen.SortOption
    var passAction: (_ reload: Bool) async -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            // Dynamic Icon based on Sort
            Group {
                if selectedSort == .priceAsc {
                    Image(systemName: "arrow.up.circle.fill")
                } else if selectedSort == .priceDesc {
                    Image(systemName: "arrow.down.circle.fill")
                } else {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
            .frame(width: 20)
            
            Text(selectedSort == .discountPct ? "Sort".localized : selectedSort.displayName)
                .lineLimit(1)
                // Layout priority removed so ViewThatFits can accurately measure intrinsic size
        }
        .font(.subheadline)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(selectedSort != .discountPct ? Color.blue.opacity(0.1) : Color(.systemGray6))
        .foregroundColor(selectedSort != .discountPct ? .blue : .primary)
        .cornerRadius(8)
        .overlay(
            Menu {
                ForEach(HomeScreen.SortOption.allCases) { option in
                    Button(action: {
                        if selectedSort != option {
                            selectedSort = option
                            Task {
                                await passAction(true)
                            }
                        }
                    }) {
                        if selectedSort == option {
                            Label(option.displayName, systemImage: "checkmark")
                        } else {
                            Text(option.displayName)
                        }
                    }
                }
            } label: {
                Color.white.opacity(0.001)
            }
        )
    }
}

struct FilterMenuContent: View {
    @Binding var selectedStore: String?
    var availableStores: [String]
    var passAction: (_ reload: Bool) async -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "line.3.horizontal.decrease.circle")
            Text(selectedStore ?? "All Stores".localized)
                .lineLimit(1)
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(selectedStore != nil ? Color.blue.opacity(0.1) : Color(.systemGray6))
        .foregroundColor(selectedStore != nil ? .blue : .primary)
        .cornerRadius(8)
        .overlay(
            Menu {
                Button("All Stores".localized) {
                    if selectedStore != nil {
                        selectedStore = nil
                        Task {
                            await passAction(true)
                        }
                    }
                }
                
                ForEach(availableStores, id: \.self) { store in
                    Button(action: {
                        if selectedStore != store {
                            selectedStore = store
                            Task {
                                await passAction(true)
                            }
                        }
                    }) {
                        if selectedStore == store {
                            Label(store, systemImage: "checkmark")
                        } else {
                            Text(store)
                        }
                    }
                }
            } label: {
                Color.white.opacity(0.001)
            }
        )
    }
}



