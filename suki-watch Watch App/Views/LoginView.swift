import SwiftUI

struct LoginView: View {
    @State private var viewModel = LoginViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image("SukiStageLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .frame(maxWidth: .infinity)

                TextField("Email", text: $viewModel.email)
                    .textInputAutocapitalization(.never)

                SecureField("Password", text: $viewModel.password)

                if viewModel.isLoading {
                    ProgressView()
                }

                Button("Log In") {
                    Task { await viewModel.signIn() }
                }
                .disabled(viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
