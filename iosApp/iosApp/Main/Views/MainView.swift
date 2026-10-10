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
                    )
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
                    authViewModel: .init(networkClient: networkClient)
                )
            }
        }
    }
}
