import SwiftUI
import SharedLogic

@MainActor
final class MapViewModelObserver: ObservableObject {

    let viewModel: MapViewModel

    init(viewModel: MapViewModel) {
        self.viewModel = viewModel

        viewModel.observeState {
            Task { @MainActor [weak self] in
                self?.objectWillChange.send()
            }
        }
    }
}