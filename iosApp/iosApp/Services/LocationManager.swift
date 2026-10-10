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

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()

        case .authorizedAlways, .authorizedWhenInUse:
            requestCurrentLocation()

        case .denied, .restricted:
            errorMessage = "Location permission is disabled. Enable it in Settings."

        @unknown default:
            errorMessage = "Unable to determine location permission."
        }
    }

    func requestCurrentLocation() {
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            requestPermission()
            return
        }

        isLoadingLocation = true
        errorMessage = nil
        manager.requestLocation()
    }

    func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            requestCurrentLocation()

        case .denied, .restricted:
            isLoadingLocation = false
            errorMessage = "Location access is denied."

        case .notDetermined:
            break

        @unknown default:
            isLoadingLocation = false
            errorMessage = "Unknown location authorization status."
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else {
            isLoadingLocation = false
            errorMessage = "Could not determine your location."
            return
        }

        currentLocation = location
        isLoadingLocation = false
        errorMessage = nil
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        isLoadingLocation = false
        errorMessage = error.localizedDescription
    }
}