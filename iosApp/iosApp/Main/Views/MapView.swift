//
//  MapView.swift
//  iosApp
//
//  Created by Vijay Thakur on 10/10/26.
//

import SwiftUI
import MapKit
import CoreLocation
import SharedLogic

struct MapView: View {
    let viewModel: GroupViewModel
    let safeRegionViewModel: SafeRegionViewModel

    @Environment(AppRouter.self) private var appRouter

    @State private var locationManager = LocationManager()
    
    @State private var groups: [SharedLogic.Group] = []
    @State private var selectedGroupID: String?

    @State private var safeRegions: [SharedLogic.SafeRegion] = []
    @State private var isLoadingRegions = false
    @State private var hasFetchedRegions = false

    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showCreateGroup = false
    @State private var showManageGroup = false
    @State private var showCreateRegion = false

    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedRadius = 200

    @State private var cameraPosition: MapCameraPosition = .automatic
    
    @State private var mapSize: CGSize = .zero

    private var selectedGroup: SharedLogic.Group? {
        groups.first { $0.id == selectedGroupID }
    }

    private var hasSafeRegion: Bool {
        !safeRegions.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && groups.isEmpty {
                    ProgressView("Loading groups...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else if groups.isEmpty {
                    ContentUnavailableView {
                        Label("No Groups Yet", systemImage: "person.3")
                    } description: {
                        Text("Create a group to start sharing locations.")
                    } actions: {
                        GTButton("Create Group") {
                            showCreateGroup = true
                        }
                    }

                } else {
                    mapContent
                }
            }
            .navigationTitle("Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !groups.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showManageGroup = true
                        } label: {
                            Image(systemName: "person.2.badge.gearshape")
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateGroup = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                locationManager.requestPermission()
                await fetchGroups()
            }
            .onChange(of: locationManager.currentLocation) { _, location in
                guard let location else { return }

                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: location.coordinate,
                        latitudinalMeters: 1500,
                        longitudinalMeters: 1500
                    )
                )
            }
            .onChange(of: selectedGroupID) { _, groupID in
                guard let groupID else {
                    safeRegions = []
                    hasFetchedRegions = false
                    return
                }

                Task {
                    await fetchSafeRegions(for: groupID)
                }
            }
            .sheet(isPresented: $showCreateGroup) {
                NavigationStack {
                    CreateGroupView(viewModel: viewModel) { createdGroup in
                        groups.append(createdGroup)
                        selectedGroupID = createdGroup.id
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("", systemImage: "xmark") {
                                showCreateGroup = false
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showManageGroup) {
                if let selectedGroup {
                    ManageGroupView(
                        selectedGroup: selectedGroup,
                        viewModel: viewModel
                    )
                }
            }
            .sheet(isPresented: $showCreateRegion) {
                if let coordinate = selectedCoordinate,
                   let selectedGroup,
                   !hasSafeRegion {
                    CreateSafeRegionView(
                        groupID: selectedGroup.id,
                        coordinate: coordinate,
                        onSave: { name, radius in
                            saveSafeRegionDraft(
                                groupID: selectedGroup.id,
                                coordinate: coordinate,
                                name: name,
                                radius: radius
                            )
                        },
                        onCancel: {
                            showCreateRegion = false
                        }
                    )
                }
            }
            .alert(
                "Something Went Wrong",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: {
                        if !$0 {
                            errorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Map

    private var mapContent: some View {
        VStack(spacing: 0) {
            membersSection
                .padding(.vertical, 12)

            MapReader { proxy in
                Map(position: $cameraPosition) {
                    UserAnnotation()

                    ForEach(safeRegions, id: \.id) { region in
                        let coordinate = CLLocationCoordinate2D(
                            latitude: region.latitude,
                            longitude: region.longitude
                        )

                        Annotation(
                            region.name,
                            coordinate: coordinate,
                            anchor: .bottom
                        ) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.title)
                                .foregroundStyle(.red)
                        }

                        MapCircle(
                            center: coordinate,
                            radius: CLLocationDistance(region.radiusMeters)
                        )
                        .foregroundStyle(.blue.opacity(0.15))
                        .stroke(.blue, lineWidth: 2)
                    }

                    if !hasSafeRegion,
                       let coordinate = selectedCoordinate {
                        Annotation(
                            "New Safe Region",
                            coordinate: coordinate,
                            anchor: .bottom
                        ) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.title)
                                .foregroundStyle(.orange)
                        }

                        MapCircle(
                            center: coordinate,
                            radius: CLLocationDistance(selectedRadius)
                        )
                        .foregroundStyle(.orange.opacity(0.15))
                        .stroke(.orange, lineWidth: 2)
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                .simultaneousGesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            guard !hasSafeRegion,
                                  hasFetchedRegions,
                                  !isLoadingRegions,
                                  let coordinate = proxy.convert(
                                      value.location,
                                      from: .local
                                  ) else {
                                return
                            }

                            selectedCoordinate = coordinate
                            showCreateRegion = true
                        }
                )
                .overlay(alignment: .top) {
                    if hasFetchedRegions,
                       !hasSafeRegion,
                       !isLoadingRegions {
                        Label(
                            "Tap the map to select a safe-region location",
                            systemImage: "mappin.and.ellipse"
                        )
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.top, 12)
                        .allowsHitTesting(false)
                    }

                    if isLoadingRegions {
                        ProgressView("Loading safe regions...")
                            .padding(12)
                            .background(.regularMaterial, in: Capsule())
                            .padding(.top, 12)
                    }
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
            }
        }
    }

    // MARK: - Members

    private var membersSection: some View {
        HStack(spacing: 16) {
            ScrollView(.horizontal) {
                HStack(spacing: 16) {
                    if let selectedGroup {
                        ForEach(selectedGroup.members, id: \.id) { member in
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(.quaternary)
                                    .frame(width: 48, height: 48)
                                    .overlay {
                                        Text(
                                            String(member.fullName.prefix(1))
                                                .uppercased()
                                        )
                                        .font(.headline)
                                    }

                                Text(member.fullName)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .frame(width: 64)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .scrollIndicators(.hidden)

            Picker(
                "Selected Group",
                selection: $selectedGroupID
            ) {
                ForEach(groups, id: \.id) { group in
                    Text(group.name)
                        .tag(Optional(group.id))
                }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: - Fetch Safe Regions

    @MainActor
    private func fetchSafeRegions(for groupID: String) async {
        guard let accessToken = GTKeychainStore.shared.accessToken,
              !accessToken.isEmpty else {
            errorMessage = "Please log in to view safe regions."
            return
        }


        isLoadingRegions = true
        hasFetchedRegions = false
        safeRegions = []
        selectedCoordinate = nil

        defer {
            isLoadingRegions = false
        }

        do {
            let result = try await safeRegionViewModel.fetchSafeRegionsByGroupID(
                groupID: groupID,
                accessToken: accessToken
            )

//            if safeRegionViewModel.uiState.value.isSessionExpired {
//                GTKeychainStore.shared.clearTokens()
//                GTKeychainStore.shared.clearClientID()
//                appRouter.logout()
//                return
//            }

            guard selectedGroupID == groupID else {
                return
            }

            guard let result else {
                errorMessage = "Safe regions could not be fetched."
                return
            }

            safeRegions = result.data
            hasFetchedRegions = true

            if let region = safeRegions.first {
                let center = CLLocationCoordinate2D(
                    latitude: region.latitude,
                    longitude: region.longitude
                )

                cameraPosition = .region(
                    fittedCameraRegion(
                        center: center,
                        radiusMeters: CLLocationDistance(region.radiusMeters)
                    )
                )
            }

        } catch {
            guard selectedGroupID == groupID else {
                return
            }

            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Save Safe Region

    private func saveSafeRegionDraft(
        groupID: String,
        coordinate: CLLocationCoordinate2D,
        name: String,
        radius: Int
    ) {
        Task { @MainActor in
            do {
                guard let accessToken = GTKeychainStore.shared.accessToken,
                      !accessToken.isEmpty else {
                    errorMessage = "Please log in to create a safe region."
                    return
                }

                let result = try await safeRegionViewModel.createSafeRegion(
                    groupID: groupID,
                    name: name,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    radiusMeters: Int32(radius),
                    accessToken: accessToken
                )

                guard selectedGroupID == groupID else {
                    showCreateRegion = false
                    return
                }

                guard let result else {
                    errorMessage = "Safe region could not be created."
                    return
                }

                // Update the map immediately with the created region.
                safeRegions = [result.data]
                hasFetchedRegions = true
                selectedCoordinate = nil
                selectedRadius = radius
                showCreateRegion = false

                cameraPosition = .region(
                    fittedCameraRegion(
                        center: coordinate,
                        radiusMeters: CLLocationDistance(radius)
                    )
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Fetch Groups

    @MainActor
    private func fetchGroups() async {
        guard !isLoading else { return }

        guard let accessToken = GTKeychainStore.shared.accessToken,
              !accessToken.isEmpty else {
            errorMessage = "Please log in to view your groups."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await viewModel.fetchGroups(
                accessToken: accessToken
            )

            if result.sessionExpired {
                GTKeychainStore.shared.clearTokens()
                GTKeychainStore.shared.clearClientID()
                appRouter.logout()
                return
            }

            guard let fetchedGroups = result.data as? [SharedLogic.Group] else {
                if let error = result.error {
                    errorMessage = error
                }
                return
            }

            groups = fetchedGroups

            if !groups.contains(where: { $0.id == selectedGroupID }) {
                selectedGroupID = groups.first?.id
            }

        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func fittedCameraRegion(
        center: CLLocationCoordinate2D,
        radiusMeters: CLLocationDistance
    ) -> MKCoordinateRegion {
        let width = max(mapSize.width, 1)

        // Circle should occupy approximately 65% of the map width.
        let visibleDiameter = radiusMeters * 2 / 0.75

        // Extra vertical space keeps the circle comfortably visible.
        let visibleHeight = visibleDiameter * (width / max(mapSize.height, 1))

        return MKCoordinateRegion(
            center: center,
            latitudinalMeters: max(visibleHeight, visibleDiameter),
            longitudinalMeters: visibleDiameter
        )
    }
}
