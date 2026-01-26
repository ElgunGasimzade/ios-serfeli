import Foundation

// MARK: - API Constants
struct APIConstants {
     static let baseURL = "https://newbackjs.onrender.com/api/v1"
//    static let baseURL = "http://localhost:8080/api/v1"
}

// MARK: - Auth
struct AuthResponse: Codable {
    let token: String
    let guestId: String
    let isNewUser: Bool
}

// MARK: - Home Feed
struct HomeFeedResponse: Codable {
    let hero: Hero?
    let categories: [Category]
    let products: [Product]
}

struct Hero: Codable {
    let title: String
    let subtitle: String
    let product: Product
}

struct Category: Codable, Identifiable {
    let id: String
    let name: String
    let selected: Bool?
}

struct Product: Codable, Identifiable {
    let id: String
    let name: String
    let brand: String?
    let category: String?
    let store: String?
    let imageUrl: String
    let price: Double
    let originalPrice: Double?
    let discountPercent: Int?
    let badge: String?
    let inStock: Bool
}

// MARK: - Scan
struct ScanResponse: Codable {
    let scanId: String
    let detectedItems: [DetectedItem]
}

struct DetectedItem: Codable, Identifiable {
    let id: String
    let name: String
    let confidence: Double
    let boundingBox: BoundingBox?
    let dealAvailable: Bool
    let imageUrl: String?
}

struct BoundingBox: Codable {
    let x, y, w, h: Double
}

// MARK: - Brand Selection
struct BrandSelectionResponse: Codable {
    let groups: [BrandGroup]?
}

struct BrandGroup: Codable, Identifiable {
    var id: String { itemName } // Computed ID for SwiftUI
    let itemName: String
    let itemDetails: String
    let status: String
    let options: [BrandItem]
}

struct BrandItem: Codable, Identifiable {
    let id: String
    let brandName: String
    let logoUrl: String
    let dealText: String
    let savings: Double
    let isSelected: Bool
    let price: Double?
    let originalPrice: Double?
    let badge: String?
    let distance: Double?
    let estTime: String?
}

// MARK: - Planning / Route
struct OptimizeRequest: Codable {
    let ids: [String] // Changed from items to ids
}


struct OptimizeResponse: Codable {
    let options: [RouteOption]
}

struct RouteOption: Codable, Identifiable {
    let id: String
    let type: String
    let title: String
    let totalSavings: Double
    let totalDistance: String
    let description: String?
    let stops: [RouteStopSummary]
}

struct RouteStopSummary: Codable, Identifiable {
    var id: String { store + summary }
    let store: String
    let summary: String
}

struct RouteDetails: Codable {
    let totalSavings: Double
    let estTime: String
    let stops: [RouteStore]
}

struct RouteStore: Codable, Identifiable {
    var id: Int { sequence }
    let sequence: Int
    let store: String
    let distance: String
    let color: String
    let items: [RouteItem]
}

struct RouteItem: Codable, Identifiable {
    let id: String
    let name: String
    let aisle: String
    let price: Double
    let savings: Double
    let checked: Bool
}

// MARK: - Trip Summary
struct TripSummary: Codable {
    let totalSavings: Double
    let timeSpent: String
    let lifetimeEarnings: Double
    let chartData: [Double]
    let dealsScouted: Int
    let wagePerHour: Double
}

// MARK: - Watchlist
struct WatchlistResponse: Codable {
    let items: [WatchlistItem]
    let popularEssentials: [String]
}

struct WatchlistItem: Codable, Identifiable {
    let id: String
    let name: String
    let status: String
    let subtitle: String
    let badge: String?
    let iconType: String
}

struct TripSummaryResponse: Codable {
    let totalSavings: Double
    let timeSpent: String
    let lifetimeEarnings: Double
    let chartData: [Double]? // Make optional or empty if not used
    let dealsScouted: Int
    let wagePerHour: Double
}

// MARK: - Search
struct SearchResponse: Codable {
    let query: String
    let count: Int
    let results: [Product]
}

struct StoreLocation: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let lat: Double?
    let lon: Double?
}
