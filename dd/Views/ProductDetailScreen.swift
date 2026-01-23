import SwiftUI

struct ProductDetailScreen: View {
    let product: Product
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var localization: LocalizationManager
    
    var body: some View {
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
                            Label(store, systemImage: "storefront")
                                .font(.caption)
                                .foregroundColor(.blue)
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
                    
                    Divider()
                    
                    // Badges / Info
                    HStack(spacing: 12) {
                        if product.inStock {
                            Label("In Stock".localized, systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("Out of Stock".localized, systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                        
                        if let category = product.category {
                            Label(category, systemImage: "tag.fill")
                                .foregroundColor(.orange)
                        }
                    }
                    .font(.subheadline)
                    
                    Spacer(minLength: 20)
                    
                    // Action Button
                    Button(action: {
                        // TODO: Add to Watchlist Logic
                    }) {
                        HStack {
                            Image(systemName: "cart.badge.plus")
                            Text("Add to List".localized)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(14)
                        .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .edgesIgnoringSafeArea(.top)
    }
}
