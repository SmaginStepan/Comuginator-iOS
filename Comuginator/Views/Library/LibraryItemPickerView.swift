import SwiftUI
import PhotosUI

struct LibraryItemPickerView: View {
    let onSelect: (String) -> Void

    @StateObject private var vm = LibraryItemPickerViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var tab: Tab = .library
    @State private var searchText = ""
    @State private var selectedSetId: String? = nil
    @State private var showCamera = false
    @State private var photosPickerItem: PhotosPickerItem?

    enum Tab: String, CaseIterable {
        case library = "Library"
        case arasaac = "ARASAAC"
        case upload  = "Add New"
    }

    private let columns = [GridItem(.adaptive(minimum: 90, maximum: 120), spacing: 10)]

    var body: some View {
        NavigationStack {
            Group {
                if vm.pendingImage != nil || vm.pendingArasaacItem != nil {
                    confirmationView
                } else {
                    mainPicker
                }
            }
            .navigationTitle("Choose Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task { await vm.load() }
        // Camera sheet
        .sheet(isPresented: $showCamera) {
            CameraPickerView { image in
                vm.setPendingImage(image)
                showCamera = false
            } onDismiss: {
                showCamera = false
            }
            .ignoresSafeArea()
        }
        // Photo library
        .onChange(of: photosPickerItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    vm.setPendingImage(image)
                }
                photosPickerItem = nil
            }
        }
        // Set filter loads items for that set
        .onChange(of: selectedSetId) { _, id in
            Task {
                if let id { await vm.loadSet(id) }
                else { await vm.load() }
            }
        }
    }

    // MARK: - Main picker

    private var mainPicker: some View {
        VStack(spacing: 0) {
            Picker("Source", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()

            switch tab {
            case .library:  libraryTab
            case .arasaac:  arasaacTab
            case .upload:   uploadTab
            }
        }
    }

    // MARK: - Library tab

    private var libraryTab: some View {
        VStack(spacing: 0) {
            // Set filter
            if !vm.sets.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(label: "All", isSelected: selectedSetId == nil) {
                            selectedSetId = nil
                        }
                        ForEach(vm.sets, id: \.id) { set in
                            FilterChip(label: set.name, isSelected: selectedSetId == set.id) {
                                selectedSetId = set.id
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
            }

            if vm.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.allItems.isEmpty {
                ContentUnavailableView("No Items", systemImage: "photo.on.rectangle")
            } else {
                let items = vm.allItems.filter {
                    searchText.isEmpty || $0.label.localizedCaseInsensitiveContains(searchText)
                }
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(items, id: \.id) { item in
                            Button {
                                onSelect(item.id)
                                dismiss()
                            } label: {
                                ItemTileView(label: item.label, imageUrl: item.imageUrl)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                .searchable(text: $searchText, prompt: "Search")
            }
        }
    }

    // MARK: - ARASAAC tab

    private var arasaacTab: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Search ARASAAC…", text: $vm.arasaacQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await vm.searchArasaac() } }
                Button("Search") { Task { await vm.searchArasaac() } }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)

            if vm.isSearchingArasaac {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.arasaacResults.isEmpty {
                ContentUnavailableView("Search for Symbols",
                    systemImage: "magnifyingglass",
                    description: Text("Type a keyword and tap Search"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(vm.arasaacResults, id: \.id) { item in
                            Button { vm.selectArasaacItem(item) } label: {
                                ItemTileView(label: item.label ?? item.id, imageUrl: item.imageUrl)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }

            if !vm.statusText.isEmpty {
                Text(vm.statusText).font(.caption).foregroundStyle(.secondary).padding(.horizontal)
            }
        }
    }

    // MARK: - Upload tab

    private var uploadTab: some View {
        VStack(spacing: 16) {
            Spacer()
            Button {
                showCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            PhotosPicker(selection: $photosPickerItem, matching: .images) {
                Label("Choose from Photos", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Confirmation view

    private var confirmationView: some View {
        VStack(spacing: 20) {
            // Image preview
            Group {
                if let img = vm.pendingImage {
                    Image(uiImage: img)
                        .resizable().scaledToFit()
                } else if let urlStr = vm.pendingArasaacItem?.imageUrl {
                    AuthImageView(urlString: urlStr)
                        .scaledToFit()
                }
            }
            .frame(width: 180, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Label field
            TextField("Label", text: $vm.pendingLabel)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            if !vm.statusText.isEmpty {
                Text(vm.statusText).font(.caption).foregroundStyle(.red)
            }

            HStack(spacing: 16) {
                Button("Cancel") { vm.cancelPending() }
                    .buttonStyle(.bordered)
                Button("Add to Library") {
                    Task {
                        let itemId: String?
                        if vm.pendingImage != nil {
                            itemId = await vm.uploadAndConfirm()
                        } else {
                            itemId = await vm.confirmArasaac()
                        }
                        if let id = itemId {
                            onSelect(id)
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isUploading)
            }

            if vm.isUploading { ProgressView("Uploading…") }

            Spacer()
        }
        .padding()
        .navigationTitle("Confirm")
    }
}

// MARK: - Filter chip

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(LocalizedStringKey(label))
                .font(.caption)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.secondary.opacity(0.15),
                            in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Item tile

private struct ItemTileView: View {
    let label: String
    let imageUrl: String?
    var body: some View {
        VStack(spacing: 4) {
            AuthImageView(urlString: imageUrl)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(label)
                .font(.caption2).lineLimit(2).multilineTextAlignment(.center)
                .frame(width: 72)
        }
        .padding(6)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Camera picker

private struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture, onDismiss: onDismiss) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onDismiss: () -> Void
        init(onCapture: @escaping (UIImage) -> Void, onDismiss: @escaping () -> Void) {
            self.onCapture = onCapture; self.onDismiss = onDismiss
        }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onCapture(image) }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onDismiss() }
    }
}
