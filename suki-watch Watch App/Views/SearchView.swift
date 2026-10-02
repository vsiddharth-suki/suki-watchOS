import SwiftUI

struct SearchView: View {
    @Binding var path: [AppRoute]
    @State private var viewModel = SearchViewModel()

    var body: some View {
        List {
            TextField("Patient name", text: $viewModel.query)
                .onSubmit { Task { await viewModel.search() } }

            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.errorMessage {
                Text(error).font(.caption2).foregroundStyle(.red)
            }

            ForEach(viewModel.results, id: \.stableId) { patient in
                Button {
                    guard let id = patient.id else { return }
                    path.append(.patientProfile(patientId: id, patientName: patient.displayName, appointmentId: nil))
                } label: {
                    VStack(alignment: .leading) {
                        Text(patient.displayName)
                        if let mrn = patient.mrn, !mrn.isEmpty {
                            Text("MRN \(mrn)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Search")
        .onChange(of: viewModel.query) { _, newValue in
            guard newValue.count >= 2 else { return }
            Task { await viewModel.search() }
        }
    }
}
