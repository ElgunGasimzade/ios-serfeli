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
        let savedRange = UserDefaults.standard.double(forKey: "searchRangeKm")
        let hasSavedEnabledPref = UserDefaults.standard.object(forKey: "isLocationEnabled") != nil
        let savedEnabled = hasSavedEnabledPref
            ? UserDefaults.standard.bool(forKey: "isLocationEnabled")
            : true // Default to enabled on fresh install
        
        self.isLocationEnabled = savedEnabled
        self.searchRangeKm = (savedRange == 0) ? 2.0 : savedRange
        
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        
        // On the very first launch (no saved pref), save the default true value
        if !hasSavedEnabledPref {
            UserDefaults.standard.set(true, forKey: "isLocationEnabled")
        }
        
        // Always check/request permission at startup if location is enabled
        if isLocationEnabled {
            requestLocation()
        }
    }
    
    func requestLocation() {
        // Only request authorization — startUpdatingLocation is called in the delegate
        // callback once permission is confirmed, avoiding the race condition.
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
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
