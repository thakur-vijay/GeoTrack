import SwiftUI
import SharedLogic

struct ContentView: View {
    @State private var appRouter: AppRouter = .init()

    private let networkClient = NetworkClientImpl(
        baseURL: "https://geotrack-backend-lyia.onrender.com/api/v1"
    )

    var body: some View {
        Group {
            switch appRouter.appState {
            case .auth:
                LoginView(
                    router: appRouter.authRouter,
                    viewModel: .init(networkClient: networkClient),
                    groupViewModel: .init(networkClient: networkClient)
                )

            case .main:
                MainView(
                    router: appRouter.mainRouter,
                    networkClient: networkClient,
                    socketManager: networkClient.socketManager
                )
            }
        }
        .environment(appRouter)
        .task {
            appRouter.initial()
        }
    }
}
