import SwiftUI

struct BrandSelectionScreen: View {
    var scanId: String?
    @State private var response: BrandSelectionResponse?
    @State private var isLoading = true
    @State private var selectedIds: [String] = []
    @EnvironmentObject var localization: LocalizationManager
    @ObservedObject var locationManager = LocationManager.shared // Observe location changes
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 300)
            } else if let groups = response?.groups {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header info matching HTML
                        HStack {
                            Text("Review Items".localized)
                                .font(.title3).bold()
                            Spacer()
                            Text("2/8")
                                .font(.caption).bold()
                                .foregroundColor(.green)
                                .padding(8)
                                .background(Color.green.opacity(0.1))
                                .clipShape(Circle())
                        }
                        
                        Text("Please review the deals we found. You can choose a specific brand or stick with your generic request.".localized)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        // Debug/Info: Show if location is active
                        if locationManager.isLocationEnabled && locationManager.location == nil {
                             Text("Locating...".localized)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }

                        // Auto-Select Buttons
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                AutoSelectButton(title: "Cheapest", icon: "tag.fill", color: .green) {
                                    autoSelect(strategy: .cheapest)
                                }
                                AutoSelectButton(title: "Max Savings", icon: "arrow.down.circle.fill", color: .blue) {
                                    autoSelect(strategy: .maxSavings)
                                }
                                AutoSelectButton(title: "Closest", icon: "location.fill", color: .orange) {
                                    autoSelect(strategy: .closest)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        ForEach(groups) { group in
                            if group.status == "DEAL_FOUND" {
                                DealFoundCard(group: group, selectedIds: $selectedIds)
                            } else {
                                NoDealFoundCard(group: group)
                            }
                        }
                    }
                    .padding()
                }
                .background(Color(UIColor.systemGroupedBackground))
                
                // Navigation to Plan
                NavigationLink(destination: ShoppingPlanScreen(selectedIds: selectedIds)) {
                    VStack(spacing: 4) {
                        Text("Start Shopping".localized)
                            .font(.headline)
                        if selectedIds.count > 0 {
                            Text("\(selectedIds.count) item(s) ready")
                                .font(.caption)
                                .opacity(0.9)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                    .padding()
                }
            } else {
                 Text("No deals found".localized)
            }
        }
        .navigationTitle("Review Items".localized)
        .task {
            await loadData()
        }
        // Re-fetch when location arrives (fixing the "first load no location" bug)
        .onChange(of: locationManager.location) { newLoc in
            if newLoc != nil {
                Task {
                    // Only reload if we haven't already loaded "with distance"? 
                    // Or just simple reload to be safe.
                    // To avoid loops, maybe check if we already have distance data? 
                    // But re-fetching is safer and cheap enough here.
                    await loadData()
                }
            }
        }
    }
    
    // Extracted fetch logic
    private func loadData() async {
        // If already loading and not first load? No, simplest is just overwrite.
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
            if let firstUrl = group.options.first?.logoUrl {
                AsyncImage(url: URL(string: firstUrl)) { image in
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
                    HStack {
                        Image(systemName: "checkmark.seal.fill").foregroundColor(.blue)
                        Text("Best Value Found".localized).foregroundColor(.white).bold()
                    }
                    .padding()
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
                        isSelected: activeSelectionId == option.id || (activeSelectionId == nil && option.isSelected)
                    )
                    .onTapGesture {
                        withAnimation {
                            // Update Only Source of Truth
                            selectedIds.removeAll { id in group.options.contains { $0.id == id } }
                            selectedIds.append(option.id)
                        }
                    }
                    // Add transition for smoother expand/collapse
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Expand/Collapse Button
                if group.options.count > 1 {
                    Button(action: {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Text(isExpanded ? "Show Less" : "See \(group.options.count - 1) More Options")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        }
                        .foregroundColor(.blue)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
                
                Button(action: { /* Add to list action */ }) {
                    Text("Add to List".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
            .padding(20)
            .background(Color.white)
        }
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .onAppear {
            // Initial Default Population only if nothing selected yet
            if activeSelectionId == nil {
                if let defaultOption = group.options.first(where: { $0.isSelected }) {
                    selectedIds.append(defaultOption.id)
                } else if let first = group.options.first {
                     // Fallback if no isSelected flag
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
                    Text(badge.uppercased())
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
                        Text("SAVE \(String(format: "%.2f", option.savings)) ₼")
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
    @EnvironmentObject var localization: LocalizationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "cart.badge.minus") // Approximation
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
