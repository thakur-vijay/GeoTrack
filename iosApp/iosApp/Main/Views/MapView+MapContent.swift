//
//  MapView+MapContent.swift
//  iosApp
//
//  Created by Vijay Thakur on 11/10/26.
//

import SwiftUI
import MapKit
import CoreLocation
import SharedLogic

extension MapView {

    // MARK: - Map

    var mapContent: some View {
        VStack(spacing: 0) {
            membersSection
                .padding(.vertical, 12)

            map
        }
    }

    private var map: some View {
        MapReader { proxy in
            Map(position: $cameraPosition, scope: mapScope) {
                memberAnnotations
                safeRegionOverlays
                newSafeRegionOverlay
            }
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        handleMapTap(
                            at: value.location,
                            proxy: proxy
                        )
                    }
            )
            .overlay(alignment: .top) {
                mapStatusOverlay
            }
            .overlay(alignment: .bottomTrailing) {
                mapControls
            }
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            mapSize = geometry.size
                        }
                        .onChange(of: geometry.size) { _, newSize in
                            mapSize = newSize
                        }
                }
            }
            .mapScope(mapScope)
        }
    }

    // MARK: - Member Annotations

    @MapContentBuilder
    private var memberAnnotations: some MapContent {
        if let selectedGroup = mapViewModel.selectedGroup.value as? SharedLogic.Group{
            ForEach(selectedGroup.members, id: \.id) { member in
                if let coordinate = memberLocations[member.id] {
                    Annotation(
                        member.fullName,
                        coordinate: .init(
                            latitude: coordinate.latitude,
                            longitude: coordinate.longitude
                        ),
                        anchor: .bottom
                    ) {
                        VStack(spacing: 4) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.blue)
                                .background(.white, in: Circle())

                            Text(member.fullName)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(
                                    .regularMaterial,
                                    in: Capsule()
                                )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Safe Region Overlays

    @MapContentBuilder
    private var safeRegionOverlays: some MapContent {
        ForEach(((mapViewModel.safeRegions.value as? [SharedLogic.SafeRegion]) ?? []), id: \.id) { region in
            MapCircle(
                center: CLLocationCoordinate2D(
                    latitude: region.latitude,
                    longitude: region.longitude
                ),
                radius: CLLocationDistance(region.radiusMeters)
            )
            .foregroundStyle(.blue.opacity(0.15))
            .stroke(.blue, lineWidth: 2)
        }
    }

    @MapContentBuilder
    private var newSafeRegionOverlay: some MapContent {
        if !mapViewModel.hasSafeRegion,
           let coordinate = mapViewModel.selectedCoordinate.value as? MapCoordinate, let selectedRadius = mapViewModel.selectedRadius.value as? Int{
            MapCircle(
                center: .init(latitude: coordinate.latitude, longitude: coordinate.longitude),
                radius: CLLocationDistance(selectedRadius)
            )
            .foregroundStyle(.orange.opacity(0.15))
            .stroke(.orange, lineWidth: 2)
        }
    }

    // MARK: - Map Interaction

    private func handleMapTap(
        at point: CGPoint,
        proxy: MapProxy
    ) {
        guard mapViewModel.canCreateSafeRegion(userId: GTKeychainStore.shared.userId),
              let coordinate = proxy.convert(point, from: .local) else {
            return
        }
        mapViewModel.setSelectedCoordinate(value: .init(latitude: coordinate.latitude, longitude: coordinate.longitude))
        mapViewModel.setShowCreateRegion(value: true)
    }

    // MARK: - Map Overlays

    @ViewBuilder
    private var mapStatusOverlay: some View {
        if (mapViewModel.isLoadingRegions.value as? Bool) ?? false {
            ProgressView("Loading safe regions...")
                .padding(12)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 12)

        } else if mapViewModel.canCreateSafeRegion(userId: GTKeychainStore.shared.userId) {
            Label(
                "Tap the map to select a safe-region location",
                systemImage: "mappin.and.ellipse"
            )
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 30)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .padding(.top, 12)
            .allowsHitTesting(false)
        }
    }

    private var mapControls: some View {
        VStack(spacing: 12) {
            MapUserLocationButton(scope: mapScope)
            MapCompass(scope: mapScope)
            MapPitchToggle(scope: mapScope)
        }
    }

    // MARK: - Camera

    func fittedCameraRegion(
        center: CLLocationCoordinate2D,
        radiusMeters: CLLocationDistance
    ) -> MKCoordinateRegion {
        let width = max(mapSize.width, 1)
        let height = max(mapSize.height, 1)

        let visibleDiameter = radiusMeters * 2 / 0.65
        let visibleHeight = visibleDiameter * (width / height)

        return MKCoordinateRegion(
            center: center,
            latitudinalMeters: max(visibleHeight, visibleDiameter),
            longitudinalMeters: visibleDiameter
        )
    }
}
