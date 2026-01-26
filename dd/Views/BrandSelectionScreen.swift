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
}

// MARK: - Subviews

struct DealFoundCard: View {
    let group: BrandGroup
    @Binding var selectedIds: [String]
    @EnvironmentObject var localization: LocalizationManager
    
    // Computed property to find active selection from the Source of Truth
    private var activeSelectionId: String? {
        group.options.first(where: { selectedIds.contains($0.id) })?.id
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
                
                ForEach(group.options) { option in
                    BrandOptionRow(
                        option: option,
                        isSelected: activeSelectionId == option.id || (activeSelectionId == nil && option.isSelected)
                    )
                    .onTapGesture {
                        // Update Only Source of Truth
                        selectedIds.removeAll { id in group.options.contains { $0.id == id } }
                        selectedIds.append(option.id)
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
                }
            }
        }
    }
}

struct BrandOptionRow: View {
    let option: BrandItem
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: option.logoUrl)) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Color.gray.opacity(0.1)
            }
            .frame(width: 56, height: 56) // Resized to 56x56
            .padding(4)
            .background(Color.white)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(option.brandName).font(.body).bold()
                    // Show badge only if present
                    if let badge = option.badge {
                        Text(badge)
                            .font(.caption2).bold()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1)) // Green for "Cheapest"
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
                
                // Location Info
                HStack(spacing: 4) {
                    Text(option.dealText).font(.caption).foregroundColor(.gray)
                    if let dist = option.distance {
                        Text("• \(String(format: "%.1f", dist)) km").font(.caption).foregroundColor(.gray)
                    }
                    if let time = option.estTime {
                        Text("• \(time)").font(.caption).foregroundColor(.gray)
                    }
                }
                
                HStack(alignment: .firstTextBaseline) {
                    Text("\(String(format: "%.2f", option.price ?? 0)) ₼").bold()
                    Text("Save \(String(format: "%.2f", option.savings)) ₼")
                        .font(.caption).foregroundColor(.green)
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
            } else {
                Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                .frame(width: 24, height: 24)
            }
        }
        .padding()
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
