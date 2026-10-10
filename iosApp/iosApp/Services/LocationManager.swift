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
final class LocationManager: NSObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    private(set) var currentLocation: CLLocation?
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var isLoadingLocation = false
    private(set) var errorMessage: String?

    private var isUpdatingLocation = false

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
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

        guard location.horizontalAccuracy >= 0 else { return }

        currentLocation = location
        isLoadingLocation = false
        errorMessage = nil

        print(
            "📍 Location updated: \(location.coordinate.latitude), " +
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
