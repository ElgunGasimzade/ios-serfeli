import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    // Determine localization context if needed, but usually .localized suffix is enough
    
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

struct ProductCard: View {
    let product: Product
    var onAdd: (() -> Void)? = nil // Optional add action
    var isAdded: Bool = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
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
                
                Text(product.name)
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                
                Text(product.store ?? "")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                Spacer() // Pushes price to the bottom
                
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(String(format: "%.2f", product.price)) ₼").bold()
                        if let original = product.originalPrice {
                            Text("\(String(format: "%.2f", original)) ₼")
                                .font(.caption2).strikethrough().foregroundColor(.gray)
                        } else {
                            Text(" ") // Invisible spacer to maintain height
                                .font(.caption2)
                        }
                    }
                    Spacer()
                    if let discount = product.discountPercent {
                        Text("-\(discount)%")
                            .font(.caption).bold()
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(10)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 3)
            
            // Optional Heart Button
            if let onAdd = onAdd {
                Button(action: onAdd) {
                    Image(systemName: isAdded ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundColor(isAdded ? .red : .gray)
                        .padding(8)
                        .background(Color.white.opacity(0.8))
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
                .padding(8)
            }
        }
        .frame(height: 240)
    }
}
