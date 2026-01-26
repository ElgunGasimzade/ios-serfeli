import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var permissionStatus: CLAuthorizationStatus = .notDetermined
    
    // User Preferences
    @Published var isLocationEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isLocationEnabled, forKey: "isLocationEnabled")
            if isLocationEnabled {
                requestLocation()
            } else {
                stopLocation()
            }
        }
    }
    
    @Published var searchRangeKm: Double {
        didSet {
            UserDefaults.standard.set(searchRangeKm, forKey: "searchRangeKm")
        }
    }
    
    override init() {
        let savedEnabled = UserDefaults.standard.bool(forKey: "isLocationEnabled")
        let savedRange = UserDefaults.standard.double(forKey: "searchRangeKm")
        
        self.isLocationEnabled = savedEnabled
        self.searchRangeKm = (savedRange == 0) ? 5.0 : savedRange
        
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        
        if isLocationEnabled {
            requestLocation()
        }
    }
    
    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func stopLocation() {
        locationManager.stopUpdatingLocation()
        location = nil
    }
    
    // Delegate Methods
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        permissionStatus = manager.authorizationStatus
        if permissionStatus == .authorizedWhenInUse || permissionStatus == .authorizedAlways {
            if isLocationEnabled {
                manager.startUpdatingLocation()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        self.location = loc
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location Error: \(error.localizedDescription)")
    }
}
