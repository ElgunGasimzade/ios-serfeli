import SwiftUI

struct BrandSelectionScreen: View {
    var scanId: String?
    var preloadedGroups: [BrandGroup]? // Allow manual injection
    var onCommit: (([String]) -> Void)? // Callback for adding to plan directly
    @State private var response: BrandSelectionResponse?
    @State private var isLoading = true
    @State private var customBrands: [String: String] = [:] // Map Group.itemName -> Custom Brand Text
    @State private var selectedIds: [String] = []
    @EnvironmentObject var localization: LocalizationManager
    @ObservedObject var locationManager = LocationManager.shared // Observe location changes
    
    // ... (totalSavings computed property remains same)
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
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 300)
            } else if let groups = response?.groups {
                ScrollView {
                    // ... (rest of UI same)
                    VStack(alignment: .leading, spacing: 24) {
                        // Header info
                        HStack {
                            Text("Review Items".localized).font(.title3).bold()
                            Spacer()
                            // Only show count if in scan mode, otherwise just hide or show static?
                            // For watchlist single item, maybe hide "2/8"?
                            if scanId != nil {
                                Text("\(groups.count) " + "Items".localized) 
                                   .font(.caption).bold()
                                   .foregroundColor(.green)
                            }
                        }
                        
                        Text(scanId != nil ? "Please review the deals we found.".localized : "Select the best deal for your item.".localized)
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        // ... (auto select buttons same)
                         // Auto-Select Buttons
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                AutoSelectButton(title: "Cheapest".localized, icon: "tag.fill", color: .green) {
                                    autoSelect(strategy: .cheapest)
                                }
                                AutoSelectButton(title: "Max Savings".localized, icon: "arrow.down.circle.fill", color: .blue) {
                                    autoSelect(strategy: .maxSavings)
                                }
                                AutoSelectButton(title: "Closest".localized, icon: "location.fill", color: .orange) {
                                    autoSelect(strategy: .closest)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        ForEach(groups) { group in
                            VStack(spacing: 0) {
                                if group.status == "DEAL_FOUND" {
                                    DealFoundCard(group: group, selectedIds: $selectedIds, customBrands: $customBrands)
                                } else {
                                    NoDealFoundCard(group: group, customBrands: $customBrands)
                                }
                            }
                        }
                    }
                    .padding()
                }
                .background(Color(UIColor.systemGroupedBackground))
                
                // Logic for "Unselected" items
                // If an item has NO selected ID, we check if it has a custom brand.
                // If neither, we assume "Generic" (just item name) IF the user proceeds.
                
                // Helper to gather all "Names" (Generic + Custom) for items without IDs
                var extraItems: [String] {
                    var items: [String] = []
                    for group in groups {
                        // Check if ANY option in this group is selected
                        let isSelected = group.options.contains { selectedIds.contains($0.id) }
                        
                        if !isSelected {
                            // If not selected, check for custom brand
                            if let custom = customBrands[group.itemName], !custom.isEmpty {
                                if custom != "[SKIPPED]" {
                                    items.append("\(group.itemName) (\(custom))")
                                }
                            } else if group.status != "DEAL_FOUND" && customBrands[group.itemName] != "[SKIPPED]" {
                                items.append(group.itemName)
                            }
                        }
                    }
                    return items
                }

                if let onCommit = onCommit {
                    Button(action: {
                        // The onCommit closure expects [String] (selectedIds)
                        // If we need to pass generic items, the signature of onCommit needs to change.
                        // For now, we adhere to the existing signature.
                        onCommit(selectedIds)
                    }) {
                        VStack(spacing: 4) {
                            Text("Add to List".localized)
                                .font(.headline)
                            if selectedIds.count > 0 {
                                Text("\(selectedIds.count) \("item(s)".localized) • \("Save".localized) \(String(format: "%.2f", totalSavings)) ₼")
                                    .font(.caption)
                                    .opacity(0.9)
                            } else {
                                Text("Select an item".localized)
                                    .font(.caption)
                                    .opacity(0.9)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedIds.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(12)
                        .padding()
                    }
                    .disabled(selectedIds.isEmpty)
                } else {
                    // SHOP FLOW (NavigationLink)
                    NavigationLink(destination: ShoppingPlanScreen(selectedIds: selectedIds, items: extraItems)) {
                        VStack(spacing: 4) {
                            Text("Start Shopping".localized)
                                .font(.headline)
                            
                            let count = selectedIds.count + extraItems.count // Total items
                             if count > 0 {
                                Text("\(count) \("item(s) ready".localized) (\("Save".localized) \(String(format: "%.2f", totalSavings)) ₼)")
                                    .font(.caption)
                                    .opacity(0.9)
                            } else {
                                Text("Select items".localized)
                                    .font(.caption)
                                    .opacity(0.9)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background((selectedIds.count + extraItems.count) == 0 ? Color.gray : Color.green)
                        .cornerRadius(12)
                        .padding()
                    }
                    .disabled((selectedIds.count + extraItems.count) == 0)
                }
            } else {
                 Text("No deals found".localized)
            }
        }

        .task {
            await loadData()
        }
        .onChange(of: locationManager.location) { newLoc in
            if newLoc != nil && scanId != nil { // Only reload on location if scanning? Or always?
                Task { await loadData() }
            }
        }
    }
    
    private func loadData() async {
        if let preloaded = preloadedGroups {
            self.response = BrandSelectionResponse(groups: preloaded)
            self.isLoading = false
            return
        }
        
        do {
            response = try await APIService.shared.getBrands(scanId: scanId)
        } catch {
            print("Error fetching brands: \(error)")
        }
        isLoading = false
    }

    // Auto-Select Logic
    enum AutoSelectStrategy {
        case cheapest
        case maxSavings
        case closest
    }

    private func autoSelect(strategy: AutoSelectStrategy) {
        guard let groups = response?.groups else { return }
        
        var newSelection: [String] = []
        
        for group in groups {
            guard !group.options.isEmpty else { continue }
            
            var bestOption: BrandItem?
            
            switch strategy {
            case .cheapest:
                bestOption = group.options.min(by: { ($0.price ?? 0) < ($1.price ?? 0) })
            case .maxSavings:
                bestOption = group.options.max(by: { $0.savings < $1.savings })
            case .closest:
                // Filter options that have distance, then sort
                // If none have distance, fallback to first
                let validOptions = group.options.filter { $0.distance != nil }
                if !validOptions.isEmpty {
                    bestOption = validOptions.min(by: { ($0.distance ?? 0) < ($1.distance ?? 0) })
                } else {
                    bestOption = group.options.first
                }
            }
            
            if let best = bestOption ?? group.options.first {
                newSelection.append(best.id)
            }
        }
        
        // Update state with animation
        withAnimation {
            selectedIds = newSelection
            // Clear all custom brands when auto-selecting
            customBrands.removeAll()
        }
    }
}

struct AutoSelectButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.caption).bold()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Subviews

struct DealFoundCard: View {
    let group: BrandGroup
    @Binding var selectedIds: [String]
    @Binding var customBrands: [String: String]
    @EnvironmentObject var localization: LocalizationManager
    @State private var isExpanded = false
    
    // Computed property to find active selection from the Source of Truth
    private var activeSelectionId: String? {
        group.options.first(where: { selectedIds.contains($0.id) })?.id
    }
    
    // Ordered options: Selected item first, then the rest
    private var orderedOptions: [BrandItem] {
        guard let activeId = activeSelectionId,
              let selectedOption = group.options.first(where: { $0.id == activeId }) else {
            return group.options
        }
        
        var others = group.options.filter { $0.id != activeId }
        // Optional: Keep others sorted by price or original order? 
        // Original order is usually best unless we want to enforce specific sorting.
        // Let's keep original order for others.
        return [selectedOption] + others
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Image (First available)
            if let firstUrl = group.options.first?.logoUrl, 
               let url = URL(string: firstUrl), 
               firstUrl.lowercased().hasPrefix("http") { // Simple validation
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(height: 140)
                .clipped()
                .overlay(
                    LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                )
                .overlay(alignment: .bottomLeading) {
                    if activeSelectionId == nil {
                        HStack {
                            Image(systemName: "slash.circle.fill").foregroundColor(.orange)
                            Text("Skipped".localized).foregroundColor(.white).bold()
                        }
                        .padding()
                    } else if let activeId = activeSelectionId, 
                              let activeOption = group.options.first(where: { $0.id == activeId }),
                              activeOption.savings > 0 {
                         HStack {
                             Image(systemName: "checkmark.seal.fill").foregroundColor(.blue)
                             Text("Best Value Found".localized).foregroundColor(.white).bold()
                         }
                         .padding()
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "cart")
                    .padding(10)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                    
                    VStack(alignment: .leading) {
                        Text(group.itemName).font(.headline)
                        Text(group.itemDetails).font(.caption).foregroundColor(.gray)
                    }
                }
                
                // Options List
                let optionsToShow = isExpanded ? orderedOptions : Array(orderedOptions.prefix(1))
                
                ForEach(optionsToShow) { option in
                    BrandOptionRow(
                        option: option,
                        isSelected: activeSelectionId == option.id // Strict check
                    )
                    .onTapGesture {
                        withAnimation {
                            // Update Only Source of Truth
                            selectedIds.removeAll { id in group.options.contains { $0.id == id } }
                            selectedIds.append(option.id)
                            // Clear custom brand if deal selected
                            customBrands[group.itemName] = ""
                            // Collapse list on selection
                            isExpanded = false
                        }
                    }
                    // Add transition for smoother expand/collapse
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Auto-Select best option if not defined
                // (Logic handled in parent onAppear, or here if we want robust card)
                
                // Custom Brand Input
                if isExpanded || activeSelectionId == nil {
                     TextField("Or enter your own brand...".localized, text: Binding(
                         get: { 
                             let val = customBrands[group.itemName] ?? ""
                             return val == "[SKIPPED]" ? "" : val
                         },
                         set: { newValue in 
                             if !newValue.isEmpty {
                                 withAnimation {
                                     selectedIds.removeAll { id in group.options.contains { $0.id == id } }
                                 }
                             }
                             if newValue.isEmpty && customBrands[group.itemName] == "[SKIPPED]" {
                                 // Leave it skipped if it is already
                             } else {
                                 customBrands[group.itemName] = newValue 
                             }
                         }
                     ))
                     .textFieldStyle(RoundedBorderTextFieldStyle())
                     .padding(.top, 4)
                }
                
                // Expand/Collapse Button
                if group.options.count > 1 {
                    Button(action: {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Text(isExpanded ? "Show Less".localized : String(format: "See %d More Options".localized, group.options.count - 1))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Image(systemName: "chevron.down")
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        }
                        .foregroundColor(.blue)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
                
                // Skip Button
                Button(action: {
                    withAnimation {
                         selectedIds.removeAll { id in group.options.contains { $0.id == id } }
                         if customBrands[group.itemName] == "[SKIPPED]" {
                             customBrands.removeValue(forKey: group.itemName)
                         } else {
                             customBrands[group.itemName] = "[SKIPPED]"
                         }
                    }
                }) {
                    let isSkipped = customBrands[group.itemName] == "[SKIPPED]"
                    Text(isSkipped ? "Item Skipped - Tap to Undo".localized : "Skip this item (Generic)".localized)
                        .font(.subheadline)
                        .foregroundColor(isSkipped ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isSkipped ? Color.gray : Color.clear)
                        .cornerRadius(8)
                }
            }
            .padding(20)
            .background(Color.white)
        }
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .onAppear {
            // Initial Default Population only if nothing selected yet AND we haven't explicitly skipped (length check?)
            // We can't distinguish "not yet loaded" from "skipped" easily unless we track initialized state.
            // But since selectedIds starts empty, we assume on first load we want to select defaults.
            // However, checking if selectedIds intersects with group options is enough to know if "something" is selected.
            // If we assume "empty == default needed", then we can't persistent "skip" if we navigate away and back?
            // For now, simple logic: Pre-select if empty intersection.
            if group.options.first(where: { selectedIds.contains($0.id) }) == nil {
                if let defaultOption = group.options.first(where: { $0.isSelected }) {
                    selectedIds.append(defaultOption.id)
                } else if let first = group.options.first {
                     selectedIds.append(first.id)
                }
            }
        }
    }
}

struct BrandOptionRow: View {
    let option: BrandItem
    let isSelected: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Product Image
            AsyncImage(url: URL(string: option.logoUrl)) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Color.gray.opacity(0.1)
            }
            .frame(width: 60, height: 60)
            .padding(4)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.1)))
            
            // Middle Content: Title, Store Info
            VStack(alignment: .leading, spacing: 6) {
                // Title (Full Width now)
                Text(option.brandName)
                    .font(.system(size: 14, weight: .medium)) // Slightly smaller, cleaner
                    .lineLimit(4) // Allow even more lines
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1) // Prioritize text space
                
                // Store & Location Info (Gray, smaller)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.dealText) // "at Store Name"
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if let dist = option.distance {
                        Text("\(String(format: "%.1f", dist)) km • \(option.estTime ?? "")")
                            .font(.system(size: 11, weight: .bold)) // Bold as requested
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer(minLength: 8) // flexible spacer
            
            // Right Side: Price, Badge, Checkmark
            VStack(alignment: .trailing, spacing: 4) {
                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                } else {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
                
                Spacer()
                
                // Badge moved here
                if let badge = option.badge {
                    Text(badge.localized.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }
                
                // Pricing Block
                VStack(alignment: .trailing, spacing: 2) {
                    if let original = option.originalPrice, original > (option.price ?? 0) {
                        Text("\(String(format: "%.2f", original)) ₼")
                            .font(.caption2)
                            .strikethrough()
                            .foregroundColor(.gray)
                    }
                    
                    Text("\(String(format: "%.2f", option.price ?? 0)) ₼")
                        .font(.headline)
                        .bold()
                    
                    if option.savings > 0.01 {
                        Text("Save".localized.uppercased() + " \(String(format: "%.2f", option.savings)) ₼")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(4)
                    }
                }
            }
            .frame(minWidth: 80) // Ensure right side doesn't shrink too much
        }
        .padding(12)
        .background(isSelected ? Color.blue.opacity(0.05) : Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

struct NoDealFoundCard: View {
    let group: BrandGroup
    @Binding var customBrands: [String: String]
    @EnvironmentObject var localization: LocalizationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "cart.badge.minus")
                    .padding(10)
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
                
                VStack(alignment: .leading) {
                    Text(group.itemName).font(.headline).foregroundColor(.gray)
                    Text(group.itemDetails).font(.caption).foregroundColor(.gray)
                }
                Spacer()
                Text("No Deals".localized)
                    .font(.caption).bold()
                    .padding(6)
                    .background(Color.gray.opacity(0.1))
                    .foregroundColor(.gray)
                    .cornerRadius(8)
            }
            
            HStack {
                Image(systemName: "magnifyingglass")
                Text("No discounts found nearby".localized)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(10)
            .foregroundColor(.gray)
            
            // Custom Brand Input
            TextField("Enter brand manually...".localized, text: Binding(
                 get: { 
                     let val = customBrands[group.itemName] ?? ""
                     return val == "[SKIPPED]" ? "" : val
                 },
                 set: { newValue in 
                     if newValue.isEmpty && customBrands[group.itemName] == "[SKIPPED]" {
                         // Leave it skipped
                     } else {
                         customBrands[group.itemName] = newValue 
                     }
                 }
            ))
            .textFieldStyle(RoundedBorderTextFieldStyle())
            
            // Skip Button placed after Custom Brand Input
            HStack {
                Text(customBrands[group.itemName] == "[SKIPPED]" ? "Item Skipped - Tap to Undo".localized : "Skip this item (Generic)".localized)
                    .font(.caption)
                    .bold()
                    .foregroundColor(customBrands[group.itemName] == "[SKIPPED]" ? .white : .red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(customBrands[group.itemName] == "[SKIPPED]" ? Color.red : Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .onTapGesture {
                        withAnimation {
                            if customBrands[group.itemName] == "[SKIPPED]" {
                                customBrands.removeValue(forKey: group.itemName)
                            } else {
                                customBrands[group.itemName] = "[SKIPPED]"
                            }
                        }
                    }
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}
