import SwiftUI

struct RootView: View {
    @Bindable private var session = SessionStore.shared
    @State private var path: [AppRoute] = []

    var body: some View {
        Group {
            if session.isLoggedIn {
                NavigationStack(path: $path) {
                    HomeView(path: $path)
                        .navigationDestination(for: AppRoute.self) { route in
                            destination(for: route)
                        }
                }
            } else {
                LoginView()
            }
        }
        .onChange(of: session.isAuthenticated) { _, authenticated in
            if !authenticated {
                path.removeAll()
            }
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .schedule:
            ScheduleView(path: $path)
        case .search:
            SearchView(path: $path)
        case let .patientProfile(patientId, patientName, appointmentId):
            PatientProfileView(path: $path, patientId: patientId, patientName: patientName, appointmentId: appointmentId)
        case let .note(noteId, patientId, patientName):
            NoteView(path: $path, noteId: noteId, patientId: patientId, patientName: patientName)
        case let .ambient(context):
            AmbientFlowView(launch: context)
        }
    }
}
