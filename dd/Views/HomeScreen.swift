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
    @EnvironmentObject var localization: LocalizationManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let feed = homeFeed {
                        // Custom Header
                        HStack(spacing: 12) {
                            Image("HeaderLogo")
                                .resizable()
                                .renderingMode(.original) // Force original colors
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                            Text("Daily Deals".localized)
                                .font(.largeTitle)
                                .bold()
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)

                        // Search Bar
                        SearchBar(text: $searchQuery)
                            .padding(.horizontal)
                        
                        if searchQuery.isEmpty {
                            // Standard Home Feed
                            
                            // Hero Section
                            if let hero = feed.hero {
                                HeroSection(hero: hero)
                                    .padding(.horizontal)
                            }
                            
                            // Categories
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(feed.categories) { category in
                                        CategoryPill(category: category)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
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
                            .padding(.horizontal)
                            
                            // Bottom Loader
                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        } else {
                            // Search Results Mode
                            if searchResults.isEmpty {
                                if searchQuery.count >= 2 {
                                    Text("No items found".localized)
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, 50)
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
                                .padding(.horizontal)
                            }
                        }
                        
                    } else {
                        ProgressView("Loading...".localized)
                            .frame(maxWidth: .infinity, minHeight: 200)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Daily Deals".localized)
            .navigationBarHidden(true)
            .task {
                await loadFeed(reload: true)
            }
            .task(id: searchQuery) {
                if searchQuery.count >= 2 {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s debounce
                    if Task.isCancelled { return }
                    do {
                        searchResults = try await APIService.shared.searchProducts(query: searchQuery)
                    } catch {
                        print("Search error: \(error)")
                    }
                } else {
                    searchResults = []
                }
            }
            .alert(isPresented: $showError) {
                Alert(title: Text("Error"), message: Text(errorMessage ?? "Unknown error"), dismissButton: .default(Text("OK"), action: {
                    Task { await loadFeed(reload: true) }
                }))
            }
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
            let response = try await APIService.shared.getHomeFeed(page: currentPage, limit: 20)
            
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

struct SearchBar: View {
    @Binding var text: String
    @EnvironmentObject var localization: LocalizationManager
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search products...".localized, text: $text)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct HeroSection: View {
    let hero: Hero
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(hero.title).font(.title2).bold()
                Spacer()
                Text(hero.subtitle).font(.caption).foregroundColor(.blue)
            }
            
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: hero.product.imageUrl)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(height: 200)
                .clipped()
                .cornerRadius(16)
                
                if let badge = hero.product.badge {
                    Text(badge)
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
                    Text(hero.product.brand ?? "").font(.caption).foregroundColor(.gray)
                    Text(hero.product.name).font(.headline)
                }
                Spacer()
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

struct ProductCard: View {
    let product: Product
    
    var body: some View {
        VStack(alignment: .leading) {
            AsyncImage(url: URL(string: product.imageUrl)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    Color.gray.opacity(0.1)
                }
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
            
            Text(product.name).font(.subheadline).lineLimit(1)
            Text(product.category ?? "").font(.caption).foregroundColor(.gray)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("\(String(format: "%.2f", product.price)) ₼").bold()
                    if let original = product.originalPrice {
                        Text("\(String(format: "%.2f", original)) ₼")
                            .font(.caption2).strikethrough().foregroundColor(.gray)
                    }
                }
                Spacer()
                if let discount = product.discountPercent {
                    Text("-\(discount)%")
                        .font(.caption).bold()
                        .padding(4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
            }
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 3)
    }
}
