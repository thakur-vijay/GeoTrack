//
//  MapViewModelObserver.swift
//  iosApp
//
//  Created by Vijay Thakur on 11/10/26.
//


import SwiftUI
import SharedLogic

@MainActor
final class MapViewModelObserver: ObservableObject {

    let viewModel: MapViewModel
    let socketManager: MapSocketManager

    private var hasStarted = false

    init(
        viewModel: MapViewModel,
        socketManager: MapSocketManager
    ) {
        self.viewModel = viewModel
        self.socketManager = socketManager
    }

    func startObserving() {
        guard !hasStarted else { return }
        hasStarted = true

        viewModel.observeState { [weak self] in
            Task { @MainActor in
                self?.objectWillChange.send()
            }
        }

        socketManager.observeState { [weak self] in
            Task { @MainActor in
                self?.objectWillChange.send()
            }
        }

        objectWillChange.send()
    }
}
