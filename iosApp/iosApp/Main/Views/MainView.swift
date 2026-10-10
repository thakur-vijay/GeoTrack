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
    var body: some View {
        TabView(selection: $router.activeTab) {
            Tab.init(
                TabModel.map.rawValue,
                systemImage: TabModel.map.symbolImage,
                value: .map
            ) {
                MapView(
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
                    socketManager: socketManager
                )
            }
        }
        .task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        }
        .task {
            do {
                guard let accessToken = GTKeychainStore.shared.accessToken,
                      !accessToken.isEmpty else {
                    return
                }

                // Connect the shared Kotlin SocketManager here.
                try await socketManager.connect(
                    accessToken: accessToken,
                )
                print("Socket connection", socketManager.isConnected)
            }catch {
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
