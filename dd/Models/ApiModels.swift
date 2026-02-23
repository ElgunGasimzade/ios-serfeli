import Foundation

// API Configuration
struct APIConstants {
     static let baseURL = "https://newbackjs.onrender.com/api/v1"
}

// MARK: - Auth
// MARK: - Auth & User
struct User: Codable {
    let id: String
    let deviceId: String
    let email: String?
    let phone: String?
    let username: String?
}

struct AuthResponse: Codable {
    let user: User? // Made optional as some endpoints might just return success status or different structure
    let isNewUser: Bool?
}

// MARK: - Plans / History
struct RouteHistoryItem: Codable, Identifiable {
    var id: String
    var route: RouteDetails // Changed let to var
    let date: Date
    var status: String // "active", "completed"
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
    var totalSavings: Double
    var estTime: String
    var stops: [RouteStore] // Changed let to var
}

struct RouteStore: Codable, Identifiable {
    var id: Int { sequence }
    var sequence: Int
    var store: String
    var distance: String
    var color: String
    var items: [RouteItem] // Changed let to var
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
    var items: [WatchlistItem]
    let popularEssentials: [String]
}

struct WatchlistItem: Codable, Identifiable {
    let id: String
    let name: String
    var status: String
    var subtitle: String
    var badge: String?
    var iconType: String
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

// MARK: - Family Models

struct Family: Codable, Identifiable {
    let id: String
    let name: String
    let inviteCode: String
    let createdAt: String
}

struct FamilyMember: Codable, Identifiable {
    let id: String
    let username: String
    let email: String?
    let role: String
    let joinedAt: String
}

struct FamilyResponse: Codable {
    let family: Family?
    let role: String?
    let members: [FamilyMember]?
}

struct FamilyShoppingItem: Codable, Identifiable {
    let id: String
    let itemName: String
    let quantity: Int
    let status: String // "pending" or "purchased"
    let notes: String?
    let brandName: String?
    let storeName: String?
    let listId: Int?
    let price: Double?
    let originalPrice: Double?
    let productId: String?
    let addedBy: ItemUser
    let purchasedBy: ItemUser?
    let purchasedAt: String?
    let createdAt: String
    let updatedAt: String
}

struct ItemUser: Codable {
    let id: String
    let username: String
}

struct FamilyShoppingListResponse: Codable {
    let items: [FamilyShoppingItem]
}

struct ShoppingList: Codable, Identifiable {
    let id: Int
    let name: String
    let createdAt: String
    let pendingCount: Int
    let totalCount: Int
}

struct ShoppingListsResponse: Codable {
    let lists: [ShoppingList]
}

// MARK: - Family List Models

struct FamilyListItem: Codable, Identifiable {
    let id: String
    let name: String
    let inviteCode: String
    let role: String
    let createdAt: String
    let memberCount: Int
    let pendingItemsCount: Int
}

struct FamilyListResponse: Codable {
    let families: [FamilyListItem]
}

