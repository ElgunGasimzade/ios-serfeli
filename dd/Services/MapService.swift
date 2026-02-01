import SwiftUI
import CoreLocation
import MapKit

enum MapApp: String, Identifiable, CaseIterable {
    case appleMaps = "Apple Maps"
    case googleMaps = "Google Maps"
    case waze = "Waze"
    
    var id: String { rawValue }
    
    var localizedName: String {
        return NSLocalizedString(self.rawValue, comment: "")
    }
}

class MapService {
    static let shared = MapService()
    
    private init() {}
    
    func getAvailableApps() -> [MapApp] {
        var apps: [MapApp] = [.appleMaps]
        
        if UIApplication.shared.canOpenURL(URL(string: "comgooglemaps://")!) {
            apps.append(.googleMaps)
        }
        
        if UIApplication.shared.canOpenURL(URL(string: "waze://")!) {
            apps.append(.waze)
        }
        
        return apps
    }
    
    func openMap(app: MapApp, lat: Double, lon: Double, name: String = "Destination") {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        
        switch app {
        case .appleMaps:
            // Use MKMapItem for Apple Maps
            let placemark = MKPlacemark(coordinate: coordinate)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = name
            mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
            
        case .googleMaps:
            let urlStr = "comgooglemaps://?daddr=\(lat),\(lon)&directionsmode=driving"
            if let url = URL(string: urlStr), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
            
        case .waze:
            let urlStr = "waze://?ll=\(lat),\(lon)&navigate=yes"
            if let url = URL(string: urlStr), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    func searchMap(app: MapApp, query: String) {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        switch app {
        case .appleMaps:
            let urlStr = "http://maps.apple.com/?q=\(encodedQuery)"
            if let url = URL(string: urlStr) {
                UIApplication.shared.open(url)
            }
            
        case .googleMaps:
            let urlStr = "comgooglemaps://?q=\(encodedQuery)"
            if let url = URL(string: urlStr), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                // Fallback
                let browser = "https://www.google.com/maps/search/?api=1&query=\(encodedQuery)"
                if let url = URL(string: browser) {
                    UIApplication.shared.open(url)
                }
            }
            
        case .waze:
            let urlStr = "waze://?q=\(encodedQuery)"
            if let url = URL(string: urlStr), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }
}
