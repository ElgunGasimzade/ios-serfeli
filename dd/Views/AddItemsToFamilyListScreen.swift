import SwiftUI

struct AddItemsToFamilyListScreen: View {
    let familyId: String
    var listId: Int? = nil // Optional listId
    let onComplete: () async -> Void
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var localization: LocalizationManager
    @StateObject var authService = AuthService.shared
    
    // Item input state
    @State private var inputText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var suggestions: [String] = []
    @State private var shoppingList: [String] = []
    
    // Deal selection state
    @State private var showingDeals = false
    @State private var isAddingItems = false
    
    var body: some View {
        NavigationView {
            mainContent
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel".localized) {
                            dismiss()
                        }
                    }
                }
                .sheet(isPresented: $showingDeals) {
                    BrandSelectionForFamilyScreen(
                        items: shoppingList,
                        onCommit: { selectedItems in
                            Task {
                                await addSelectedToFamily(items: selectedItems)
                            }
                        }
                    )
                }
        }
    }
    
    private var mainContent: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                searchSection
                listContent
            }
            
            bottomButton
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Items to Family List".localized)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
            Text("Add items to compare prices across stores".localized)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
    
    private var searchSection: some View {
        VStack(spacing: 0) {
            searchBar
            suggestionsView
        }
        .padding(.bottom, 20)
        .zIndex(2)
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 18))
            
            TextField("Search e.g. 'milk'".localized, text: Binding(
                get: { inputText },
                set: { newValue in
                    inputText = newValue
                    performSearch(query: newValue)
                }
            ))
            .font(.system(size: 16))
            .submitLabel(.done)
            .onSubmit {
                if !inputText.isEmpty {
                    searchTask?.cancel()
                    addItem(name: inputText)
                    inputText = ""
                    suggestions = []
                }
            }
            
            if !inputText.isEmpty {
                Button(action: {
                    searchTask?.cancel()
                    addItem(name: inputText)
                    inputText = ""
                    suggestions = []
                }) {
                    Text("Add".localized)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
        .zIndex(2)
    }
    
    @ViewBuilder
    private var suggestionsView: some View {
        if !suggestions.isEmpty {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(suggestions.prefix(5), id: \.self) { suggestion in
                            suggestionRow(suggestion)
                            if suggestion != suggestions.last && suggestion != suggestions.prefix(5).last {
                                Divider().padding(.leading, 40)
                            }
                        }
                    }
                }
                .frame(maxHeight: 250)
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .zIndex(3)
        }
    }
    
    private func suggestionRow(_ suggestion: String) -> some View {
        Button(action: {
            inputText = suggestion
            suggestions = []
        }) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray.opacity(0.5))
                    .font(.system(size: 14))
                Text(suggestion)
                    .foregroundColor(.primary)
                    .font(.system(size: 16))
                Spacer()
                Image(systemName: "arrow.up.left")
                    .foregroundColor(.gray.opacity(0.5))
                    .font(.system(size: 14))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.white)
        }
    }
    
    @ViewBuilder
    private var listContent: some View {
        if shoppingList.isEmpty {
            emptyState
        } else {
            shoppingListView
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "cart.badge.plus")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.gray.opacity(0.2))
            Text("Your list is empty".localized)
                .font(.headline)
                .foregroundColor(.gray)
            Text("Start typing to add items".localized)
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.8))
            Spacer()
        }
    }
    
    private var shoppingListView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(Array(shoppingList.enumerated()), id: \.offset) { index, item in
                    itemRow(item: item, index: index)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
    }
    
    private func itemRow(item: String, index: Int) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: "bag.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 20))
            }
            
            Text(item)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    removeAtIndex(index)
                }
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.6))
                    .font(.system(size: 18))
                    .padding(8)
            }
        }
        .padding(12)
        .padding(12)
        .background(itemRowBackground)
    }
    
    private func removeAtIndex(_ index: Int) {
        if shoppingList.indices.contains(index) {
            shoppingList.remove(at: index)
        }
    }

    private var itemRowBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white)
            .shadow(color: Color.black.opacity(0.03), radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1))
    }
    
    private var bottomButton: some View {
        VStack {
            Spacer()
            Button(action: {
                print("DEBUG: Finding deals for items: \(shoppingList)")
                showingDeals = true
            }) {
                HStack {
                    Text("Find Best Deals".localized)
                        .font(.system(size: 18, weight: .bold))
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 22))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(shoppingList.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(20)
                .shadow(
                    color: shoppingList.isEmpty ? Color.clear : Color.blue.opacity(0.4),
                    radius: 10,
                    x: 0,
                    y: 4
                )
            }
            .disabled(shoppingList.isEmpty)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .zIndex(1)
    }
    
    // MARK: - Actions
    
    private func performSearch(query: String) {
        searchTask?.cancel()
        
        if query.count < 2 {
            withAnimation {
                suggestions = []
            }
            return
        }
        
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            if Task.isCancelled { return }
            
            do {
                let results = try await APIService.shared.searchKeywords(query: query)
                
                if !Task.isCancelled {
                    await MainActor.run {
                        withAnimation {
                            self.suggestions = results
                        }
                    }
                }
            } catch {
                print("Search error: \(error)")
            }
        }
    }
    
    private func addItem(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if !shoppingList.contains(where: { $0.lowercased() == trimmed.lowercased() }) {
            withAnimation {
                shoppingList.append(trimmed)
            }
        }
    }
    
    private func addSelectedToFamily(items: [(name: String, brand: String?, store: String?, price: Double?, originalPrice: Double?, productId: String?)]) async {
        isAddingItems = true
        guard let userId = AuthService.shared.userId else { return }
        
        for item in items {
            do {
                _ = try await APIService.shared.addToFamilyShoppingList(
                    familyId: familyId,
                    userId: userId,
                    itemName: item.name,
                    quantity: 1,
                    notes: nil,
                    brandName: item.brand,
                    storeName: item.store,
                    listId: listId,
                    price: item.price,
                    originalPrice: item.originalPrice,
                    productId: item.productId
                )
            } catch {
                print("Error adding item: \(error)")
            }
        }
        
        await MainActor.run {
            isAddingItems = false
        }
        
        await onComplete()
        dismiss()
    }
}

// MARK: - Wrapper for BrandSelectionScreen with Items

struct BrandSelectionForFamilyScreen: View {
    let items: [String]
    let onCommit: ([(name: String, brand: String?, store: String?, price: Double?, originalPrice: Double?, productId: String?)]) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var response: BrandSelectionResponse?
    @State private var isLoading = true
    @State private var customBrands: [String: String] = [:] // Map Group.itemName -> Custom Brand Text
    @State private var selectedIds: [String] = []
    @EnvironmentObject var localization: LocalizationManager
    @ObservedObject var locationManager = LocationManager.shared
    
    var totalSavings: Double {
        guard let groups = response?.groups else { return 0.0 }
        
        let uniqueSelectedIds = Set(selectedIds)
        var total = 0.0
        var countedIds = Set<String>()
        
        for group in groups {
            guard group.status == "DEAL_FOUND" else { continue }
            for option in group.options {
                if uniqueSelectedIds.contains(option.id) && !countedIds.contains(option.id) {
                    if let original = option.originalPrice, let price = option.price {
                        let itemSavings = original - price
                        if itemSavings > 0 {
                            total += itemSavings
                            countedIds.insert(option.id)
                        }
                    }
                }
            }
        }
        return total
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if let groups = response?.groups {
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                // Header
                                HStack {
                                    Text("Review Items".localized)
                                        .font(.title3).bold()
                                    Spacer()
                                }
                                
                                Text("Select the best deals for your items".localized)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                // Items
                                ForEach(groups) { group in
                                    if group.status == "DEAL_FOUND" {
                                        DealFoundCard(group: group, selectedIds: $selectedIds, customBrands: $customBrands)
                                    } else {
                                        NoDealFoundCard(group: group, customBrands: $customBrands)
                                    }
                                }
                            }
                            .padding()
                        }
                        .background(Color(UIColor.systemGroupedBackground))
                        
                        // Add to List Button
                        Button(action: {
                            var results: [(name: String, brand: String?, store: String?, price: Double?, originalPrice: Double?, productId: String?)] = []
                            
                            // 1. Process groups returned by API
                            for group in groups {
                                if let selectedOption = group.options.first(where: { selectedIds.contains($0.id) }) {
                                    // User selected a specific deal
                                    results.append((name: group.itemName, brand: selectedOption.brandName, store: selectedOption.dealText, price: selectedOption.price, originalPrice: selectedOption.originalPrice, productId: selectedOption.id))
                                } else {
                                    // No deal selected -> Check custom brand
                                    let custom = customBrands[group.itemName]
                                    let hasComment = !(custom?.isEmpty ?? true) && custom != "[SKIPPED]"
                                    let isNotFound = group.status != "DEAL_FOUND" || group.options.isEmpty
                                    let isSkipped = custom == "[SKIPPED]"
                                    // Add if it has a comment, or if it wasn't found (and NOT explicitly skipped)
                                    if hasComment || (isNotFound && !isSkipped) {
                                        let brandToUse = hasComment ? custom : nil
                                        results.append((name: group.itemName, brand: brandToUse, store: nil, price: nil, originalPrice: nil, productId: nil))
                                    }
                                }
                            }
                            
                            // 2. Add items that were in the original list but NOT in the API response
                            for item in items {
                                let exists = groups.contains(where: { $0.itemName.lowercased() == item.lowercased() })
                                if !exists {
                                     results.append((name: item, brand: nil, store: nil, price: nil, originalPrice: nil, productId: nil))
                                }
                            }
                            
                            onCommit(results)
                            dismiss()
                        }) {
                            VStack(spacing: 4) {
                                Text("Add to Family List".localized)
                                    .font(.headline)
                                if selectedIds.count > 0 {
                                    Text("\(selectedIds.count) \("deal(s) selected".localized) • \("Save".localized) \(String(format: "%.2f", totalSavings)) ₼")
                                        .font(.caption)
                                        .opacity(0.9)
                                } else {
                                    Text("Add items".localized)
                                        .font(.caption)
                                        .opacity(0.9)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                            .padding()
                        }
                    }
                } else {
                    Text("No deals found or failed to load".localized)
                }
            }
            .navigationTitle("Find Deals".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task {
            do {
                response = try await APIService.shared.getBrands(items: items)
                isLoading = false
            } catch {
                print("Error loading brands: \(error)")
                isLoading = false
            }
        }
    }
}

