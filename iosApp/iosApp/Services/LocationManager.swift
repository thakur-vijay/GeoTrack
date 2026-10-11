//
//  LocationManager.swift
//  iosApp
//
//  Created by Vijay Thakur on 10/10/26.
//


import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class LocationManager: NSObject, @MainActor CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    private(set) var currentLocation: CLLocation?
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var isLoadingLocation = false
    private(set) var errorMessage: String?
    
    private let minimumDistanceForUpdate: CLLocationDistance = 20
    private var lastPublishedLocation: CLLocation?

    private var isUpdatingLocation = false

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 20
        manager.activityType = .otherNavigation
        manager.pausesLocationUpdatesAutomatically = false

        // Supports location updates while the app is in the background.
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
    }

    // MARK: - Permissions

    func requestPermission() {
        authorizationStatus = manager.authorizationStatus

        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse:
            // Request Always permission for background tracking.
            manager.requestAlwaysAuthorization()

        case .authorizedAlways:
            startLocationUpdates()

        case .denied, .restricted:
            errorMessage = "Location access is disabled. Enable it in Settings."

        @unknown default:
            errorMessage = "Unable to determine location permission."
        }
    }

    // MARK: - Location Updates

    func requestCurrentLocation() {
        authorizationStatus = manager.authorizationStatus

        guard authorizationStatus == .authorizedAlways ||
              authorizationStatus == .authorizedWhenInUse else {
            requestPermission()
            return
        }

        isLoadingLocation = true
        errorMessage = nil

        // One-time location request.
        manager.requestLocation()
    }

    func startLocationUpdates() {
        authorizationStatus = manager.authorizationStatus

        guard authorizationStatus == .authorizedAlways ||
              authorizationStatus == .authorizedWhenInUse else {
            requestPermission()
            return
        }

        guard !isUpdatingLocation else { return }

        isUpdatingLocation = true
        isLoadingLocation = true
        errorMessage = nil

        manager.startUpdatingLocation()
    }

    func stopLocationUpdates() {
        manager.stopUpdatingLocation()
        isUpdatingLocation = false
        isLoadingLocation = false
    }

    // MARK: - Authorization Changes

    func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        authorizationStatus = manager.authorizationStatus

        switch authorizationStatus {
        case .authorizedAlways:
            startLocationUpdates()

        case .authorizedWhenInUse:
            // Foreground access only; background tracking may not work.
            startLocationUpdates()

        case .denied, .restricted:
            stopLocationUpdates()
            errorMessage = "Location access is denied. Enable it in Settings."

        case .notDetermined:
            break

        @unknown default:
            stopLocationUpdates()
            errorMessage = "Unknown location authorization status."
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else {
            isLoadingLocation = false
            errorMessage = "Could not determine your location."
            return
        }

        guard location.horizontalAccuracy >= 0 else {
            return
        }
        
        guard location.horizontalAccuracy <= 50 else {
            print("⏭️ Location ignored: accuracy too low")
            return
        }

        isLoadingLocation = false
        errorMessage = nil

        // First valid location is always accepted.
        guard let lastPublishedLocation else {
            self.lastPublishedLocation = location
            currentLocation = location

            print(
                "📍 Initial location: " +
                "\(location.coordinate.latitude), " +
                "\(location.coordinate.longitude)"
            )

            return
        }

        // Calculate distance from the last accepted location.
        let distance = location.distance(from: lastPublishedLocation)

        guard distance >= minimumDistanceForUpdate else {
            print(
                "⏭️ Location ignored: moved only " +
                "\(Int(distance))m; minimum is " +
                "\(Int(minimumDistanceForUpdate))m"
            )

            return
        }

        // Accept location only after the minimum movement threshold.
        self.lastPublishedLocation = location
        currentLocation = location

        print(
            "📍 Location accepted after moving \(Int(distance))m: " +
            "\(location.coordinate.latitude), " +
            "\(location.coordinate.longitude)"
        )
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        isLoadingLocation = false
        errorMessage = error.localizedDescription

        print("❌ Location error: \(error.localizedDescription)")
    }
}
