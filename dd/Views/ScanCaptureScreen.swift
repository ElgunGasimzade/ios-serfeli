import SwiftUI

struct ScanCaptureScreen: View {
    @State private var inputOb = ""
    @State private var debounceWorkItem: DispatchWorkItem?
    
    // We reuse DetectedItem as our list model
    @State private var shoppingListItems: [DetectedItem] = []
    
    @State private var suggestions: [String] = []
    @State private var isSearching = false
    @State private var navigateToDeals = false
    @State private var currentScanId: String? = nil
    
    @EnvironmentObject var localization: LocalizationManager
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Create Your List".localized)
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
                    
                    // Search Bar Section
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                                .font(.system(size: 18))
                            
                            TextField("Search e.g. 'yuyucu toz'".localized, text: Binding(
                                get: { inputOb },
                                set: { newValue in
                                    inputOb = newValue
                                    performSearch(query: newValue)
                                }
                            ))
                            .font(.system(size: 16))
                            .submitLabel(.done)
                            .onSubmit {
                                if !inputOb.isEmpty {
                                    addItem(name: inputOb)
                                    inputOb = ""
                                    suggestions = []
                                }
                            }
                            
                            if !inputOb.isEmpty {
                                // Add Button (Direct add)
                                Button(action: {
                                    addItem(name: inputOb)
                                    inputOb = ""
                                    suggestions = []
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 22))
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .padding(.horizontal)
                        .zIndex(2) // Ensure it sits above list
                        
                        // Floating Suggestions List
                        if !suggestions.isEmpty {
                            VStack(spacing: 0) {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(suggestions, id: \.self) { suggestion in
                                            Button(action: {
                                                addItem(name: suggestion)
                                                inputOb = ""
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
                                                    Image(systemName: "plus")
                                                        .foregroundColor(.blue.opacity(0.8))
                                                        .font(.system(size: 14, weight: .bold))
                                                }
                                                .padding(.vertical, 12)
                                                .padding(.horizontal, 16)
                                                .background(Color.white)
                                            }
                                            if suggestion != suggestions.last {
                                                Divider().padding(.leading, 40)
                                            }
                                        }
                                    }
                                }
                                .frame(maxHeight: 250) // Limit height
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                            .padding(.horizontal, 20) // Slightly indented from search bar width
                            .padding(.top, 4) // Spacing below search bar
                            .zIndex(3) // Above everything
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.bottom, 20)
                    .zIndex(2)

                    // Shopping List
                    if shoppingListItems.isEmpty {
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
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(shoppingListItems) { item in
                                    HStack(spacing: 16) {
                                        // Icon
                                        ZStack {
                                            Circle()
                                                .fill(Color.blue.opacity(0.1))
                                                .frame(width: 44, height: 44)
                                            Image(systemName: "bag.fill") // Or dynamic icon based on name?
                                                .foregroundColor(.blue)
                                                .font(.system(size: 20))
                                        }
                                        
                                        Text(item.name)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            withAnimation {
                                                if let index = shoppingListItems.firstIndex(where: { $0.id == item.id }) {
                                                    shoppingListItems.remove(at: index)
                                                }
                                            }
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red.opacity(0.6))
                                                .font(.system(size: 18))
                                                .padding(8)
                                        }
                                    }
                                    .padding(12)
                                    .background(Color.white)
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 100) // Space for bottom button
                        }
                    }
                }
                
                // Bottom Floating Button
                VStack {
                    Spacer()
                    Button(action: {
                        Task {
                            // Generate ID and sync with backend
                            let newScanId = UUID().uuidString
                            self.currentScanId = newScanId // Store for binding
                            
                            do {
                                // We use 'confirmScan' to save our manually built list
                                _ = try await APIService.shared.confirmScan(scanId: newScanId, items: shoppingListItems)
                                navigateToDeals = true
                            } catch {
                                print("Error syncing list: \(error)")
                                // Navigate anyway? Maybe showing error is better, but fallback is safe.
                                navigateToDeals = true
                            }
                        }
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
                        .background(shoppingListItems.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(20)
                        .shadow(color: shoppingListItems.isEmpty ? .clear : .blue.opacity(0.4), radius: 10, x: 0, y: 4)
                    }
                    .disabled(shoppingListItems.isEmpty)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .zIndex(1)
                
                // Hidden Navigation
                 NavigationLink(destination: BrandSelectionScreen(scanId: currentScanId), isActive: $navigateToDeals) {
                    EmptyView()
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private func performSearch(query: String) {
        debounceWorkItem?.cancel()
        
        if query.count < 2 {
            withAnimation {
                suggestions = []
            }
            return
        }
        
        let workItem = DispatchWorkItem {
            Task {
                do {
                    let results = try await APIService.shared.searchKeywords(query: query)
                    DispatchQueue.main.async {
                        withAnimation {
                            self.suggestions = results
                        }
                    }
                } catch {
                    print("Search error: \(error)")
                }
            }
        }
        
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
    
    private func addItem(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let newItem = DetectedItem(
            id: UUID().uuidString,
            name: trimmed,
            confidence: 1.0,
            boundingBox: nil,
            dealAvailable: true,
            imageUrl: nil
        )
        // Avoid duplicates?
        if !shoppingListItems.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            withAnimation {
                shoppingListItems.append(newItem)
            }
        }
    }
}
