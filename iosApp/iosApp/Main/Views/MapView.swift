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
    let socketManager: SocketManager

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

    @State private var memberLocations: [String: CLLocationCoordinate2D] = [:]
    @State private var isListeningForEvents = false

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
                memberLocations.removeAll()

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
        .onChange(of: locationManager.currentLocation, initial: true) { oldLocation, location in
            print("📍 [Location] onChange TRIGGERED")
            print("📍 [Location] Old: \(String(describing: oldLocation))")
            print("📍 [Location] New: \(String(describing: location))")

            guard let location else {
                print("❌ [Location] Current location is NIL")
                return
            }

            print("✅ [Location] Coordinates: \(location.coordinate.latitude), \(location.coordinate.longitude)")

            guard let groupID = selectedGroupID else {
                print("❌ [Location] selectedGroupID is NIL")
                return
            }

            print("✅ [Location] Selected Group ID: \(groupID)")
            print("🔌 [Socket] Connected: \(socketManager.isConnected)")

            let event: [String: Any] = [
                "type": "location.updated",
                "data": [
                    "group_id": groupID,
                    "latitude": location.coordinate.latitude,
                    "longitude": location.coordinate.longitude
                ]
            ]

            print("📦 [Location] Preparing event: \(event)")

            guard JSONSerialization.isValidJSONObject(event) else {
                print("❌ [Location] Invalid JSON object")
                return
            }

            guard let data = try? JSONSerialization.data(withJSONObject: event),
                  let json = String(data: data, encoding: .utf8) else {
                print("❌ [Location] JSON serialization failed")
                return
            }

            print("✅ [Location] JSON created: \(json)")
            print("📤 [Socket] Sending location event...")

            Task {
                do {
                    let sent = try await socketManager.sendEvent(event: json)

                    print("📤 [Socket] Send result: \(sent)")

                    if (sent as? Bool) ?? false{
                        print("✅ [Socket] Location event sent successfully")
                    } else {
                        print("❌ [Socket] Send returned FALSE — socket disconnected or session missing")
                    }
                } catch {
                    print("❌ [Socket] Send error: \(error.localizedDescription)")
                }
            }
        }
        .task {
             connectSocketAndReceiveEvents()
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

                    // MARK: Group Members

                    if let selectedGroup {
                        ForEach(selectedGroup.members, id: \.id) { member in
                            if let coordinate = memberLocations[member.id] {
                                Annotation(
                                    member.fullName,
                                    coordinate: coordinate,
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
                                            .background(.regularMaterial, in: Capsule())
                                    }
                                }
                            }
                        }
                    }

                    // MARK: Safe Regions

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

                    // MARK: New Safe Region

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
                        .padding(.horizontal, 30)
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
                                    .fill(
                                        memberLocations[member.id] == nil
                                            ? .gray
                                            : .green.opacity(0.2)
                                    )
                                    .frame(width: 48, height: 48)
                                    .overlay {
                                        Text(
                                            String(member.fullName.prefix(1))
                                                .uppercased()
                                        )
                                        .font(.headline)
                                    }
                                    .overlay(alignment: .bottomTrailing) {
                                        if memberLocations.contains(where: { $0.key == member.id}){
                                            Circle()
                                                .fill(.green)
                                                .frame(width: 12, height: 12)
                                                .overlay {
                                                    Circle()
                                                        .stroke(.background, lineWidth: 2)
                                                }
                                        }
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

    // MARK: - WebSocket

    @MainActor
    private func connectSocketAndReceiveEvents() {
        socketManager.watchEvents { event in
            Task { @MainActor in
                handleSocketEvent(event)
            }
        }
    }

    @MainActor
    private func handleSocketEvent(_ event: String) {
        print("📩 Received event: \(event)")

        guard
            let data = event.data(using: .utf8),
            let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let eventType = payload["type"] as? String,
            let dataPayload = payload["data"] as? [String: Any]
        else {
            print("❌ Invalid event")
            return
        }

        // MARK: - User Went Outside Safe Region
        print("Event is ", eventType)
        if eventType == "user_went_outside" {
            guard
                let user = dataPayload["user"] as? [String: Any],
                let userID = user["id"] as? String,
                let member = selectedGroup?.members.first(where: { $0.id == userID })
            else {
                print("❌ User not found in selected group")
                return
            }

            print("🚨 \(member.fullName) went outside the safe region")

            let content = UNMutableNotificationContent()
            content.title = "Safe Region Alert 🚨"
            content.body = "\(member.fullName) has left the safe region."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    print("❌ Notification failed: \(error.localizedDescription)")
                } else {
                    print("✅ Safe region notification triggered")
                }
            }

            return
        }

        // MARK: - Location Updated

        guard eventType == "location.updated" else {
            return
        }

        guard
            let userID = dataPayload["user_id"] as? String,
            let latitude = numberValue(dataPayload["latitude"]),
            let longitude = numberValue(dataPayload["longitude"])
        else {
            print("❌ Invalid location update")
            return
        }

        guard selectedGroup?.members.contains(where: { $0.id == userID }) == true else {
            print("⚠️ User \(userID) is not in selected group")
            return
        }

        memberLocations[userID] = CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude
        )

        print("✅ Updated \(userID): \(latitude), \(longitude)")
    }

    private func numberValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }

        if let string = value as? String {
            return Double(string)
        }

        return nil
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

    // MARK: - Camera

    private func fittedCameraRegion(
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
