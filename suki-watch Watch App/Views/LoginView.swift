import SwiftUI

struct LoginView: View {
    @State private var viewModel = LoginViewModel()
    @State private var selectedEnvironment = AppEnvironment.current

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(selectedEnvironment.logoImageName)
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

                Spacer(minLength: 8)

                Picker("Environment", selection: $selectedEnvironment) {
                    ForEach(AppEnvironment.allCases) { environment in
                        Text(environment.displayName).tag(environment)
                    }
                }
                .pickerStyle(.navigationLink)
                .font(.caption2)
                .onChange(of: selectedEnvironment) { _, newValue in
                    AppEnvironment.select(newValue)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
