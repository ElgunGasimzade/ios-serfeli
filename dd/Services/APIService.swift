import Foundation
import CoreLocation

enum APIError: Error, LocalizedError {
    case invalidURL
    case serverError
    case decodingError
    case serviceUnavailable
    case unauthorized
    case unknown(Error)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL."
        case .serverError: return "Server returned an error."
        case .decodingError: return "Failed to parse data."
        case .serviceUnavailable: return "Service is currently unavailable. Showing demo data."
        case .unauthorized: return "User is not authorized."
        case .unknown(let error): return error.localizedDescription
        case .cancelled: return "cancelled"
        }
    }
}

class APIService {
    static let shared = APIService()
    private init() {}
    
    // Use localhost for Simulator
    private let baseURL = APIConstants.baseURL
    
    // Helper for mock delay (can be removed if unused, but keeping simple)
    private func mockDelay() async {
        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000) // 1 sec
    }

    func getAvailableStores() async throws -> [StoreLocation] {
        var urlString = "\(baseURL)/stores"
        
        // Append Location if enabled and available
        if LocationManager.shared.isLocationEnabled, let loc = LocationManager.shared.location {
            let lat = loc.coordinate.latitude
            let lon = loc.coordinate.longitude
            let range = LocationManager.shared.searchRangeKm
            
            urlString += "?lat=\(lat)&lon=\(lon)&range=\(range)"
        }
        
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode([StoreLocation].self, from: data)
    }
    
    func getHomeFeed(page: Int = 1, limit: Int = 20, sortBy: String? = nil, storeFilter: String? = nil) async throws -> HomeFeedResponse {
        var urlString = "\(baseURL)/home/feed?page=\(page)&limit=\(limit)"
        
        if let sort = sortBy {
            urlString += "&sort=\(sort)"
        }
        
        if let store = storeFilter {
            // Encode the store name as it may contain spaces/special chars
            if let encodedStore = store.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString += "&store=\(encodedStore)"
            }
        }
        
        // Append Location if enabled and available
        if LocationManager.shared.isLocationEnabled, let loc = LocationManager.shared.location {
            let lat = loc.coordinate.latitude
            let lon = loc.coordinate.longitude
            let range = LocationManager.shared.searchRangeKm
            
            urlString += "&lat=\(lat)&lon=\(lon)&range=\(range)"
        }
        
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.setValue(LocalizationManager.shared.language, forHTTPHeaderField: "Accept-Language")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw APIError.serverError
            }
            return try JSONDecoder().decode(HomeFeedResponse.self, from: data)
        } catch {
            if (error as? URLError)?.code == .cancelled || (error as NSError).code == NSURLErrorCancelled {
                throw APIError.cancelled
            }
            print("Network failed, fallback to mock: \(error)")
             throw APIError.unknown(error)
        }
    }
    
    func searchProducts(query: String) async throws -> (products: [Product], count: Int) {
        var urlString = "\(baseURL)/search?q=\(query)"
        
        // Append Location if enabled and available
        if LocationManager.shared.isLocationEnabled, let loc = LocationManager.shared.location {
            let lat = loc.coordinate.latitude
            let lon = loc.coordinate.longitude
            let range = LocationManager.shared.searchRangeKm
            
            urlString += "&lat=\(lat)&lon=\(lon)&range=\(range)"
        }
        
        guard let encodedURL = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: encodedURL) else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
        return (searchResponse.results, searchResponse.count)
    }
    
    func searchKeywords(query: String) async throws -> [String] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/keywords/search?q=\(encodedQuery)") else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode([String].self, from: data)
    }
    
    func getBrands(scanId: String? = nil, items: [String]? = nil) async throws -> BrandSelectionResponse {

        var urlString = "\(baseURL)/deals/brands"
        var hasParams = false
        
        if let scanId = scanId {
            urlString += "?scanId=\(scanId)"
            hasParams = true
        }
        
        // Add items as comma-separated query param if provided
        if let items = items, !items.isEmpty {
            let itemsParam = items.joined(separator: ",").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            urlString += hasParams ? "&" : "?"
            urlString += "items=\(itemsParam)"
            hasParams = true
        }
        
        print("DEBUG: Fetching brands with URL: \(urlString)")
        
        // Append Location if enabled and available
        if LocationManager.shared.isLocationEnabled, let loc = LocationManager.shared.location {
            let lat = loc.coordinate.latitude
            let lon = loc.coordinate.longitude
            let range = LocationManager.shared.searchRangeKm
            
            let prefix = hasParams ? "&" : "?"
            urlString += "\(prefix)lat=\(lat)&lon=\(lon)&range=\(range)"
        }
        
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw APIError.serverError
            }
            return try JSONDecoder().decode(BrandSelectionResponse.self, from: data)
    }
    
    func processScan(imageData: Data) async throws -> ScanResponse {
        
        guard let url = URL(string: "\(baseURL)/scan/process") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"scan.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
            let (data, response) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode(ScanResponse.self, from: data)
    }
    
    // New method to confirm scan items
    func confirmScan(scanId: String, items: [DetectedItem]) async throws -> ScanResponse {

        guard let url = URL(string: "\(baseURL)/scan/\(scanId)/confirm") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try JSONEncoder().encode(items)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode(ScanResponse.self, from: data)
        } catch {
            // Mock success
            return ScanResponse(scanId: scanId, detectedItems: items)
        }
    }
    
    func getRouteOptions(ids: [String]? = nil, items: [String]? = nil) async throws -> OptimizeResponse {
        guard let url = URL(string: "\(baseURL)/planning/optimize") else { throw APIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [:]
        if let ids = ids, !ids.isEmpty {
            body["ids"] = ids
        }
        if let items = items, !items.isEmpty {
            body["items"] = items
        }
        
        if let location = LocationManager.shared.location {
            body["lat"] = location.coordinate.latitude
            body["lon"] = location.coordinate.longitude
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        return try JSONDecoder().decode(OptimizeResponse.self, from: data)
    }
    
    func getRouteDetails(optionId: String) async throws -> RouteDetails {
        guard let url = URL(string: "\(baseURL)/planning/route/\(optionId)") else { throw APIError.invalidURL }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode(RouteDetails.self, from: data)
    }
    
    func getWatchlist(userId: String) async throws -> WatchlistResponse {
        guard let url = URL(string: "\(baseURL)/watchlist?userId=\(userId)") else { throw APIError.invalidURL }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode(WatchlistResponse.self, from: data)
    }
    
    struct AddToWatchlistResponse: Codable {
        let success: Bool
        let id: String
    }

    func addToWatchlist(userId: String, name: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/watchlist") else { throw APIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "userId": userId,
            "name": name
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        let res = try JSONDecoder().decode(AddToWatchlistResponse.self, from: data)
        return res.id
    }
    
    func removeFromWatchlist(userId: String, itemId: String) async throws {
        guard let url = URL(string: "\(baseURL)/watchlist/\(itemId)?userId=\(userId)") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
    }
    
    func completeTrip(totalSavings: Double, timeSpent: String, dealsScouted: Int) async throws {
        guard let url = URL(string: "\(baseURL)/trips") else { throw APIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "totalSavings": totalSavings,
            "timeSpent": timeSpent,
            "dealsScouted": dealsScouted
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
    }
    
    func getTripSummary() async throws -> TripSummaryResponse {
        guard let url = URL(string: "\(baseURL)/trips/last") else { throw APIError.invalidURL }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode(TripSummaryResponse.self, from: data)
    }
    func deviceLogin(deviceId: String) async throws -> AuthResponse {
        guard let url = URL(string: "\(baseURL)/auth/device-login") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["deviceId": deviceId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }
    
    func updateProfile(userId: String, email: String?, phone: String?, username: String?) async throws -> AuthResponse { // Returns { success: true, user: ... }
        guard let url = URL(string: "\(baseURL)/auth/profile") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body = ["userId": userId]
        if let e = email { body["email"] = e }
        if let p = phone { body["phone"] = p }
        if let u = username { body["username"] = u }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        // The endpoint returns { success: true, user: ... }, but AuthResponse is { user, isNewUser }
        // Let's adjust expectations or struct. 
        // Backend returns: { success: true, user: { ... } }
        // Let's just define a generic update response wrapper in AuthController? 
        // For simplicity, let's just reuse AuthResponse struct and ignore isNewUser (make optional).
        
        // Actually, let's assume the swift helper returns the full object if consistent.
        // I should verify backend AuthController.updateProfile returns consistent structure. 
        // It returns { success: true, user: ... }. isNewUser is missing.
        // So decoding AuthResponse might fail if isNewUser is required.
        // Let's modify AuthResponse above or create a new one.
        // Or simpler: Reuse, map isNewUser manually?
        
        // Quick Fix: Decode as dictionary for flexibility or create a ProfileUpdateResponse struct.
        // Let's assume we decode into a temporary struct that matches the known backend response.
        
        struct ProfileUpdateResponse: Codable {
            let success: Bool
            let user: User
        }
        
        let updateRes = try JSONDecoder().decode(ProfileUpdateResponse.self, from: data)
        return AuthResponse(user: updateRes.user, isNewUser: false)
    }
    
    // Plans
    
    func savePlan(userId: String, route: RouteDetails) async throws -> String { // Returns PlanID
        guard let url = URL(string: "\(baseURL)/plans") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // JSON encode the route details
        let routeData = try JSONEncoder().encode(route)
        let routeJson = try JSONSerialization.jsonObject(with: routeData)
        
        let body: [String: Any] = [
            "userId": userId,
            "routeDetails": routeJson,
            "status": "active"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        // Expected response: { id, created_at, status }
        struct SavePlanResponse: Codable { let id: String }
        let res = try JSONDecoder().decode(SavePlanResponse.self, from: data)
        return res.id
    }
    
    // Add item to an existing plan
    func addItemToPlan(planId: String, product: Product) async throws {
        guard let url = URL(string: "\(baseURL)/plans/\(planId)/items") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "productId": product.id,
            "name": product.name,
            "brand": product.brand as Any,
            "store": product.store,
            "price": product.price,
            "originalPrice": product.originalPrice ?? product.price,
            "imageUrl": product.imageUrl as Any
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        _ = try await URLSession.shared.data(for: request)
        // Response assumed successful if no error thrown
    }
    
    // Intelligently add item to active plan or create new plan
    func addItemToActivePlan(product: Product) async throws -> String {
        guard let userId = AuthService.shared.userId else {
            throw APIError.serverError
        }
        
        
        // Fetch fresh plans from backend to ensure we have the latest status
        // Relying on RouteCacheService might be stale if not refreshed recently
        let plans = try await getPlans(userId: userId)
        let activePlan = plans.first(where: { $0.status == "active" })
        
        if let planId = activePlan?.id {
            // Add to existing active plan
            try await addItemToPlan(planId: planId, product: product)
            return planId
        } else {
            // Create new plan with this single item
            let routeItem = RouteItem(
                id: product.id,
                name: product.name,
                aisle: product.brand ?? "",
                price: product.price,
                savings: (product.originalPrice ?? product.price) - product.price,
                checked: false
            )
            
            let store = RouteStore(
                sequence: 1,
                store: product.store ?? "Unknown Store",
                distance: "0 km",
                color: "#4A90E2",
                items: [routeItem]
            )
            
            let route = RouteDetails(
                totalSavings: (product.originalPrice ?? product.price) - product.price,
                estTime: "5 min",
                stops: [store]
            )
            
            let planId = try await savePlan(userId: userId, route: route)
            return planId
        }
    }
    
    func getPlans(userId: String) async throws -> [RouteHistoryItem] {
        guard let url = URL(string: "\(baseURL)/plans/\(userId)") else { throw APIError.invalidURL }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        // Backend returns: [{ id, route_details, created_at, status, ... }]
        // Frontend RouteHistoryItem: { id, route, date, status }
        // We need to decode specifically.
        // Since property names differ ("route_details" vs "route"), we need custom decoding or backend change.
        // Let's use a Data Transfer Object (DTO) here.
        
        struct PlanDTO: Codable {
            let id: String
            let route: RouteDetails
            let date: String // Backend sends ISO string
            let status: String
        }
        
        let dtos = try JSONDecoder().decode([PlanDTO].self, from: data)
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        return dtos.map { dto in
            RouteHistoryItem(
                id: dto.id,
                route: dto.route,
                date: formatter.date(from: dto.date) ?? Date(),
                status: dto.status
            )
        }
    }
    
    func completePlan(planId: String, finalRoute: RouteDetails?) async throws {
        guard let url = URL(string: "\(baseURL)/plans/\(planId)/complete") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let route = finalRoute {
            let routeData = try JSONEncoder().encode(route)
            let routeJson = try JSONSerialization.jsonObject(with: routeData)
            let body: [String: Any] = ["routeDetails": routeJson]
             request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
    }
    
    func deletePlan(planId: String) async throws {
        guard let url = URL(string: "\(baseURL)/plans/\(planId)") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
    }
    
    // Stats
    struct UserStats: Codable {
        let totalTrips: Int
        let totalSavings: Double
    }
    
    func getStats(userId: String) async throws -> UserStats {
        guard let url = URL(string: "\(baseURL)/plans/\(userId)/stats") else { throw APIError.invalidURL }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode(UserStats.self, from: data)
    }
    
    // MARK: - Family Management
    
    func createFamily(userId: String, familyName: String) async throws -> FamilyResponse {
        guard let url = URL(string: "\(baseURL)/family/create") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["userId": userId, "familyName": familyName]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode(FamilyResponse.self, from: data)
    }
    
    func joinFamily(userId: String, inviteCode: String) async throws -> FamilyResponse {
        guard let url = URL(string: "\(baseURL)/family/join") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["userId": userId, "inviteCode": inviteCode]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode(FamilyResponse.self, from: data)
    }
    
    func getMyFamily(userId: String) async throws -> FamilyResponse {
        guard let url = URL(string: "\(baseURL)/family/my-family?userId=\(userId)") else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode(FamilyResponse.self, from: data)
    }
    
    func getFamilyList(userId: String) async throws -> FamilyListResponse {
        guard let url = URL(string: "\(baseURL)/family/list?userId=\(userId)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode(FamilyListResponse.self, from: data)
    }
    
    func leaveFamily(userId: String, familyId: String) async throws {
        guard let url = URL(string: "\(baseURL)/family/leave") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["userId": userId, "familyId": familyId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
    }
    
    // MARK: - Family Shopping Lists
    
    func createShoppingList(familyId: String, name: String) async throws -> ShoppingList {
        guard let url = URL(string: "\(baseURL)/family/shopping-lists/create") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        guard let userId = AuthService.shared.userId else { throw APIError.unauthorized }
        
        let body: [String: Any] = [
            "familyId": familyId,
            "userId": userId,
            "name": name
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        struct Response: Codable { let list: ShoppingList }
        let res = try JSONDecoder().decode(Response.self, from: data)
        return res.list
    }
    
    func getShoppingLists(familyId: String) async throws -> [ShoppingList] {
        guard let url = URL(string: "\(baseURL)/family/shopping-lists?familyId=\(familyId)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("Error fetch list: \(response)")
            throw APIError.serverError
        }
        
        let res = try JSONDecoder().decode(ShoppingListsResponse.self, from: data)
        return res.lists
    }
    
    func deleteShoppingList(listId: Int) async throws {
        guard let url = URL(string: "\(baseURL)/family/shopping-lists/\(listId)") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
    }

    // MARK: - Family Shopping List Items
    
    func getFamilyShoppingList(familyId: String, listId: Int? = nil) async throws -> FamilyShoppingListResponse {
        var urlString = "\(baseURL)/family/shopping-list?familyId=\(familyId)"
        if let listId = listId {
            urlString.append("&listId=\(listId)")
        }
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode(FamilyShoppingListResponse.self, from: data)
    }
    
    func addToFamilyShoppingList(familyId: String, userId: String, itemName: String, quantity: Int = 1, notes: String? = nil, brandName: String? = nil, storeName: String? = nil, listId: Int? = nil, price: Double? = nil, originalPrice: Double? = nil, productId: String? = nil) async throws -> FamilyShoppingItem {
        guard let url = URL(string: "\(baseURL)/family/shopping-list/add") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "familyId": familyId,
            "userId": userId,
            "itemName": itemName,
            "quantity": quantity
        ]
        
        if let notes = notes { body["notes"] = notes }
        if let brandName = brandName { body["brandName"] = brandName }
        if let storeName = storeName { body["storeName"] = storeName }
        if let listId = listId { body["listId"] = listId }
        if let price = price { body["price"] = price }
        if let originalPrice = originalPrice { body["originalPrice"] = originalPrice }
        if let productId = productId { body["productId"] = productId }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        struct Response: Codable { let item: FamilyShoppingItem }
        let res = try JSONDecoder().decode(Response.self, from: data)
        return res.item
    }
    
    func updateFamilyShoppingItem(itemId: String, status: String? = nil, purchasedBy: String? = nil, quantity: Int? = nil, notes: String? = nil, brandName: String? = nil, storeName: String? = nil, price: Double? = nil, originalPrice: Double? = nil, productId: String? = nil) async throws {
        guard let url = URL(string: "\(baseURL)/family/shopping-list/\(itemId)") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [:]
        if let s = status { body["status"] = s }
        if let u = purchasedBy { body["purchasedBy"] = u }
        if let q = quantity { body["quantity"] = q }
        if let n = notes { body["notes"] = n }
        if let b = brandName { body["brandName"] = b }
        if let st = storeName { body["storeName"] = st }
        if let p = price { body["price"] = p }
        if let op = originalPrice { body["originalPrice"] = op }
        if let pid = productId { body["productId"] = pid }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
    }
    
    func deleteFamilyShoppingItem(itemId: String) async throws {
        guard let url = URL(string: "\(baseURL)/family/shopping-list/\(itemId)") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
    }
}

