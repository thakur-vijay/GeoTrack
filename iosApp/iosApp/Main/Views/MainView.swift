//
//  MainView.swift
//  iosApp
//
//  Created by Vijay Thakur on 10/10/26.
//

import SwiftUI
import SharedLogic


struct MainView: View {
    @Bindable var router: MainRouter
    let networkClient: any NetworkClient
    let socketManager: SocketManager
    
    private let viewModel: MapViewModel
    private let mapSocketManager: MapSocketManager
    
    init(
        router: MainRouter,
        networkClient: any NetworkClient,
        socketManager: SocketManager,
    ) {
        self.router = router
        self.networkClient = networkClient
        self.socketManager = socketManager
        self.viewModel = MapViewModel(
            groupViewModel: GroupViewModel(
                networkClient: networkClient
            ),
            safeRegionViewModel: SafeRegionViewModel(
                networkClient: networkClient
            )
        )
        self.mapSocketManager = .init(mapViewModel: viewModel)
    }
    
    var body: some View {
        TabView(selection: $router.activeTab) {
            Tab.init(
                TabModel.map.rawValue,
                systemImage: TabModel.map.symbolImage,
                value: .map
            ) {
                MapView(
                    mapViewModel: viewModel,
                    mapSocketManager: mapSocketManager,
                    viewModel: GroupViewModel(
                        networkClient: networkClient
                    ),
                    safeRegionViewModel: SafeRegionViewModel(
                        networkClient: networkClient
                    ),
                    
                    socketManager: socketManager
                )
            }
            
            Tab.init(
                TabModel.settings.rawValue,
                systemImage: TabModel.settings.symbolImage,
                value: .settings
            ) {
                SettingsView(
                    viewModel: UsersViewModel(
                        networkClient: networkClient,
                    ),
                    authViewModel: .init(networkClient: networkClient),
                    socketManager: socketManager,
                    groupID: (viewModel.selectedGroup.value as? SharedLogic.Group)?.id
                )
            }
        }
        .task {
            // Register callback before connecting the socket.
            mapSocketManager.onUserWentOutside = { userID, fullName in
                Task { @MainActor in
                    let message = userID == GTKeychainStore.shared.userId ? "You have left the safe region." : "\(fullName) has left the safe region."
                    await NotificationManager.shared.sendNotification(
                        title: "Safe Region Alert 🚨",
                        body: message
                    )
                }
            }

            await NotificationManager.shared.requestPermission()

            do {
                guard let accessToken = GTKeychainStore.shared.accessToken,
                      !accessToken.isEmpty else {
                    return
                }

                try await socketManager.connect(
                    accessToken: accessToken
                )

                print("Socket connection", socketManager.isConnected)

                if (socketManager.isConnected.value as? Bool) ?? false {
                    socketManager.watchEvents { event in
                        Task { @MainActor in
                            mapSocketManager.handleSocketEvent(event: event)
                        }
                    }
                }
            } catch {
                print(error.localizedDescription)
            }
        }
        .onDisappear {
            Task {
                try? await socketManager.disconnect()
            }
        }
    }
}
