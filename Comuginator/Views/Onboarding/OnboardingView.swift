import SwiftUI

struct OnboardingView: View {
    @StateObject private var vm = OnboardingViewModel()
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Comuginator")
                    .font(.largeTitle.bold())
                    .padding(.top, 48)

                switch vm.step {
                case .nameEntry: nameSection
                case .choice:    choiceSection
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 24)
        }
        .overlay { if vm.isLoading { loadingOverlay } }
        .disabled(vm.isLoading)
        .sheet(isPresented: $vm.showQRScanner) {
            QRScannerView(
                onResult: { vm.handleQRCode($0) },
                onDismiss: { vm.showQRScanner = false }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $vm.showCreateFamilySheet) {
            createFamilySheet
        }
        .onChange(of: vm.isComplete) { _, complete in
            if complete { appState.isLoggedIn = true }
        }
    }

    // MARK: - Name entry

    private var nameSection: some View {
        VStack(spacing: 16) {
            TextField("Your name", text: $vm.userName)
                .textFieldStyle(.roundedBorder)
                .textContentType(.name)
                .autocorrectionDisabled()

            TextField("Device name", text: $vm.deviceName)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()

            Button("Next") { vm.proceedFromNameEntry() }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Create or join

    private var choiceSection: some View {
        VStack(spacing: 16) {
            Text("What would you like to do?")
                .font(.headline)

            Button("Create Family") { vm.showCreateFamilySheet = true }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)

            Button(vm.showJoinSection ? "Cancel joining" : "Join Family") {
                vm.showJoinSection.toggle()
                vm.errorMessage = nil
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)

            if vm.showJoinSection {
                joinSection
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.showJoinSection)
    }

    private var joinSection: some View {
        VStack(spacing: 12) {
            TextField("Invite code", text: $vm.inviteCode)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()

            Button {
                vm.showQRScanner = true
            } label: {
                Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button("Join") {
                Task { await vm.joinFamily() }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Create family sheet

    private var createFamilySheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Smith Family", text: $vm.familyName)
                        .autocorrectionDisabled()
                } header: {
                    Text("Family name (optional)")
                }
            }
            .navigationTitle("Create Family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { vm.showCreateFamilySheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        vm.showCreateFamilySheet = false
                        Task { await vm.createFamily() }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Loading overlay

    private var loadingOverlay: some View {
        ProgressView()
            .scaleEffect(1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
    }
}
