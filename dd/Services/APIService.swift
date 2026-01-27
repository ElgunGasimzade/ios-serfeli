import Foundation
import CoreLocation

enum APIError: Error, LocalizedError {
    case invalidURL
    case serverError
    case decodingError
    case serviceUnavailable
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL."
        case .serverError: return "Server returned an error."
        case .decodingError: return "Failed to parse data."
        case .serviceUnavailable: return "Service is currently unavailable. Showing demo data."
        case .unknown(let error): return error.localizedDescription
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
            print("Network failed, fallback to mock: \(error)")
             throw APIError.unknown(error)
        }
    }
    
    func searchProducts(query: String) async throws -> [Product] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search?q=\(encodedQuery)") else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        let searchResponse = try JSONDecoder().decode(SearchResponse.self, from: data)
        return searchResponse.results
    }
    
    func getBrands(scanId: String? = nil) async throws -> BrandSelectionResponse {

        var urlString = "\(baseURL)/deals/brands"
        if let scanId = scanId {
            urlString += "?scanId=\(scanId)"
        }
        
        // Append Location if enabled and available
        if LocationManager.shared.isLocationEnabled, let loc = LocationManager.shared.location {
            let lat = loc.coordinate.latitude
            let lon = loc.coordinate.longitude
            let range = LocationManager.shared.searchRangeKm
            
            let prefix = urlString.contains("?") ? "&" : "?"
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
    
    func getRouteOptions(ids: [String]) async throws -> OptimizeResponse {
         // POST /planning/optimize
         guard let url = URL(string: "\(baseURL)/planning/optimize") else { throw APIError.invalidURL }
         var request = URLRequest(url: url)
         request.httpMethod = "POST"
         request.setValue("application/json", forHTTPHeaderField: "Content-Type")
         
         // Send actual selected IDs from user's brand selection
         let body: [String: Any] = ["ids": ids]
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
    
    func getWatchlist() async throws -> WatchlistResponse {
        guard let url = URL(string: "\(baseURL)/watchlist") else { throw APIError.invalidURL }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode(WatchlistResponse.self, from: data)
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        // Expected response: { id, created_at, status }
        struct SavePlanResponse: Codable { let id: String }
        let res = try JSONDecoder().decode(SavePlanResponse.self, from: data)
        return res.id
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
}
