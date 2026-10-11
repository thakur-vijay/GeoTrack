import SwiftUI
import MapKit
import CoreLocation
import SharedLogic

struct MapView: View {
    let mapViewModel: MapViewModel
    let mapSocketManager: MapSocketManager
    let viewModel: GroupViewModel
    let safeRegionViewModel: SafeRegionViewModel
    let socketManager: SocketManager

    @Environment(AppRouter.self) var appRouter

    @State var locationManager = LocationManager()
    @State var cameraPosition: MapCameraPosition = .automatic
    @State var mapSize: CGSize = .zero

    @Namespace var mapScope
    
    var memberLocations: [String: MapCoordinate] {
        (mapSocketManager.memberLocations.value as? [String: MapCoordinate]) ?? [:]
    }
    
    @StateObject private var mapViewModelObserver: MapViewModelObserver
    
    init(mapViewModel: MapViewModel, mapSocketManager: MapSocketManager, viewModel: GroupViewModel, safeRegionViewModel: SafeRegionViewModel, socketManager: SocketManager) {
        self.mapViewModel = mapViewModel
        self.mapSocketManager = mapSocketManager
        self.viewModel = viewModel
        self.safeRegionViewModel = safeRegionViewModel
        self.socketManager = socketManager
        _mapViewModelObserver = StateObject(
            wrappedValue: MapViewModelObserver(
                viewModel: mapViewModel,
                socketManager: mapSocketManager
            )
        )
    }
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Groups")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    toolbarContent
                }
                .task {
                    mapViewModelObserver.startObserving()

                    locationManager.requestPermission()

                    let isSessionExpired = try? await mapViewModel.fetchGroups(
                        accessToken: GTKeychainStore.shared.accessToken ?? ""
                    )

                    if (isSessionExpired as? Bool) ?? false {
                        GTKeychainStore.shared.clearTokens()
                        appRouter.logout()
                    }
                }
                .onChange(of: locationManager.currentLocation, initial: true) { _, location in
                    handleCurrentLocationChanged(location)
                }
                .onChange(of: (mapViewModel.selectedGroup.value as? SharedLogic.Group)?.id) {
                    _,
                    groupID in
                    Task {
                        do {
                            let result = try await mapViewModel.handleSelectedGroupChanged(
                                groupID: groupID,
                                accessToken: GTKeychainStore.shared.accessToken ?? ""
                            )
                            cameraPosition = .region(
                                fittedCameraRegion(
                                    center: .init(
                                        latitude: result.center?.latitude ?? 0,
                                        longitude: result.center?.longitude ?? 0
                                    ),
                                    radiusMeters: CLLocationDistance(result.region?.radiusMeters ?? 0)
                                )
                            )
                        }catch {
                            print(error.localizedDescription)
                        }
                    }
                }
                .sheet(
                    isPresented: Binding(
                        get: { (mapViewModel.showCreateGroup.value as? Bool) ?? false },
                        set: { mapViewModel.setShowCreateGroup(value: $0) }
                    )
                ) {
                    createGroupSheet
                }
                .sheet(
                    isPresented: Binding(
                        get: { (mapViewModel.showManageGroup.value as? Bool) ?? false },
                        set: { mapViewModel.setShowManageGroup(value: $0) }
                    )
                ) {
                    manageGroupSheet
                }
                .sheet(
                    isPresented: Binding(
                        get: { (mapViewModel.showCreateRegion.value as? Bool) ?? false },
                        set: { mapViewModel.setShowCreateRegion(value: $0) }
                    )
                ) {
                    createRegionSheet
                }
                .alert(
                    "Something Went Wrong",
                    isPresented: Binding(
                        get: { mapViewModel.errorMessage.value != nil },
                        set: { if !$0 { mapViewModel.setError(message: nil) } }
                    )
                ) {
                    Button("OK", role: .cancel) {
                        mapViewModel.setError(message: nil)
                    }
                } message: {
                    Text((mapViewModel.errorMessage.value as? String) ?? "")
                }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        let groups = (mapViewModel.groups.value as? [SharedLogic.Group]) ?? []
        let isLoading = (mapViewModel.isLoading.value as? Bool) ?? false

        if isLoading && groups.isEmpty {
            ProgressView("Loading groups...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        } else if groups.isEmpty {
            emptyState

        } else {
            mapContent
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Groups Yet", systemImage: "person.3")
        } description: {
            Text("Create a group to start sharing locations.")
        } actions: {
            GTButton("Create Group") {
                mapViewModel.setShowCreateGroup(value: true)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !((mapViewModel.groups.value as? [SharedLogic.Group]) ?? []).isEmpty {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    mapViewModel.setShowManageGroup(value: true)
                } label: {
                    Image(systemName: "person.2.badge.gearshape")
                }
                .disabled(mapViewModel.selectedGroup.value == nil)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                mapViewModel.setShowCreateGroup(value: true)
            } label: {
                Image(systemName: "plus")
            }
        }
    }

    // MARK: - Sheets

    private var createGroupSheet: some View {
        NavigationStack {
            CreateGroupView(viewModel: viewModel) { createdGroup in
                mapViewModel.onGroupCreated(createdGroup: createdGroup)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("", systemImage: "xmark") {
                        mapViewModel.setShowCreateGroup(value: false)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var manageGroupSheet: some View {
        if let selectedGroup = mapViewModel.selectedGroup.value as? SharedLogic.Group{
            ManageGroupView(
                selectedGroup: selectedGroup,
                viewModel: viewModel
            )
        }
    }

    @ViewBuilder
    private var createRegionSheet: some View {
        if let coordinate = mapViewModel.selectedCoordinate.value as? MapCoordinate,
           let selectedGroup = mapViewModel.selectedGroup.value as? SharedLogic.Group,
           !mapViewModel.hasSafeRegion {
            CreateSafeRegionView(
                groupID: selectedGroup.id,
                coordinate: .init(latitude: coordinate.latitude, longitude: coordinate.longitude),
                onSave: { name, radius in
                    saveSafeRegion(
                        groupID: selectedGroup.id,
                        coordinate: coordinate,
                        name: name,
                        radius: radius
                    )
                },
                onCancel: {
                    mapViewModel.setShowCreateRegion(value: false)
                }
            )
        }
    }

    private var errorAlertPresentation: Binding<Bool> {
        Binding(
            get: {
                (mapViewModel.errorMessage as? String) != nil
            },
            set: { isPresented in
                if !isPresented {
                    mapViewModel.setError(message: nil)
                }
            }
        )
    }

    // MARK: - Location Updates

    private func handleCurrentLocationChanged(
        _ location: CLLocation?
    ) {
        print("Seding Location is ", String(describing: location))
        guard let location else {
            return
        }

        cameraPosition = .region(
            MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 1_500,
                longitudinalMeters: 1_500
            )
        )

        sendCurrentLocation(location)
    }

    private func sendCurrentLocation(
        _ location: CLLocation
    ) {
        guard let groupID = (mapViewModel.selectedGroup.value as? SharedLogic.Group)?.id else {
            return
        }

        let event: [String: Any] = [
            "type": "location.updated",
            "data": [
                "group_id": groupID,
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude
            ]
        ]

        guard JSONSerialization.isValidJSONObject(event),
              let data = try? JSONSerialization.data(
                withJSONObject: event
              ),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        Task {
            do {
                _ = try await socketManager.sendEvent(event: json)
            } catch {
                print("Location event failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Safe Region Creation

    private func saveSafeRegion(
        groupID: String,
        coordinate: MapCoordinate,
        name: String,
        radius: Int
    ) {
        Task { @MainActor in
            do {
                _ = try await mapViewModel.performSaveSafeRegion(
                    groupID: groupID,
                    coordinate: coordinate,
                    name: name,
                    radius: Int32(radius),
                    accessToken: GTKeychainStore.shared.accessToken ?? ""
                )
                cameraPosition = .region(
                    fittedCameraRegion(
                        center: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude),
                        radiusMeters: CLLocationDistance(radius)
                    )
                )
            }catch {
                print(error.localizedDescription)
            }
        }
    }
}



//32.277343075265044, 75.5122126652555
//32.285433, 75.512213
