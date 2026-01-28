import SwiftUI

struct ProductDetailScreen: View {
    let product: Product
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var localization: LocalizationManager
    
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var addedToPlanId: String?
    @State private var isAddingToPlan = false
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Product Image
                    ZStack(alignment: .topTrailing) {
                        AsyncImage(url: URL(string: product.imageUrl)) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                Color.gray.opacity(0.1)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(.gray)
                                    )
                            }
                        }
                        .frame(height: 300)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        
                        if let discount = product.discountPercent, discount > 0 {
                            Text("-\(discount)%")
                                .font(.headline)
                                .bold()
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .padding(16)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // Brand & Store Info
                        HStack {
                            if let brand = product.brand {
                                Text(brand.uppercased())
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                    .tracking(1)
                            }
                            Spacer()
                            if let store = product.store {
                                Button(action: {
                                    openGoogleMaps(for: store)
                                }) {
                                    Label(store, systemImage: "storefront")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .underline()
                                }
                            }
                        }
                        
                        // Title
                        Text(product.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Price Section
                        HStack(alignment: .lastTextBaseline, spacing: 10) {
                            Text("\(String(format: "%.2f", product.price)) ₼")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.blue)
                            
                            if let original = product.originalPrice {
                                Text("\(String(format: "%.2f", original)) ₼")
                                    .font(.title3)
                                    .strikethrough()
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // Divider and Badges removed as requested
                        
                        Spacer(minLength: 20)
                    }
                    .padding()
                }
            }
            
            // Bottom Action Button
            VStack {
                Button(action: {
                    guard !isAddingToPlan else { return }
                    isAddingToPlan = true
                    
                    Task {
                        defer { isAddingToPlan = false }
                        do {
                            let planId = try await APIService.shared.addItemToActivePlan(product: product)
                            addedToPlanId = planId
                            await RouteCacheService.shared.refreshHistory()
                            showSuccessAlert = true
                        } catch {
                            errorMessage = "Failed to add item to list: \(error.localizedDescription)"
                            showErrorAlert = true
                        }
                    }
                }) {
                    HStack {
                        if isAddingToPlan {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "cart.badge.plus")
                            Text("Add to List".localized)
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isAddingToPlan ? Color.blue.opacity(0.7) : Color.blue)
                    .cornerRadius(14)
                    .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .disabled(isAddingToPlan)
            }
            .padding()
            .background(Color.white)
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: -5)
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .toast(isPresented: $showSuccessAlert, message: "Item added to list!".localized)
        .alert("Error".localized, isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    func openGoogleMaps(for storeName: String) {
        Task {
            // 1. Fetch stores to find coords
            do {
                let stores = try await APIService.shared.getAvailableStores()
                if let match = stores.first(where: { $0.name == storeName }),
                   let lat = match.lat, let lon = match.lon {
                    
                    // Open Google Maps with Coords
                    let urlStr = "comgooglemaps://?daddr=\(lat),\(lon)&directionsmode=driving"
                    if let url = URL(string: urlStr), UIApplication.shared.canOpenURL(url) {
                        await UIApplication.shared.open(url)
                    } else {
                        // Fallback to Browser
                        let browserUrl = "https://www.google.com/maps/dir/?api=1&destination=\(lat),\(lon)"
                        if let url = URL(string: browserUrl) {
                            await UIApplication.shared.open(url)
                        }
                    }
                } else {
                    // Fallback to searching by name
                    let query = storeName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    let urlStr = "comgooglemaps://?q=\(query)"
                    if let url = URL(string: urlStr), UIApplication.shared.canOpenURL(url) {
                        await UIApplication.shared.open(url)
                    } else {
                         let browserUrl = "https://www.google.com/maps/search/?api=1&query=\(query)"
                         if let url = URL(string: browserUrl) {
                             await UIApplication.shared.open(url)
                         }
                    }
                }
            } catch {
                print("Error finding store location: \(error)")
            }
        }
    }
}
