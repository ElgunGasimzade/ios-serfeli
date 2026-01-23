import Foundation

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
    
    func getHomeFeed(page: Int = 1, limit: Int = 20) async throws -> HomeFeedResponse {
        guard let url = URL(string: "\(baseURL)/home/feed?page=\(page)&limit=\(limit)") else { throw APIError.invalidURL }
        
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
}
