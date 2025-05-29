import SwiftUI
import PhotosUI
import AVFoundation
import UIKit

/// Erweiterte PhotoPicker-Komponente für Memory-Erstellung
/// Unterstützt Multiple Selection, Kamera, Komprimierung und Offline-Storage
struct PhotoPicker: View {
    @StateObject private var viewModel = PhotoPickerViewModel()
    @Binding var selectedImages: [UIImage]
    @Binding var isPresented: Bool
    
    let maxSelections: Int
    let allowsCamera: Bool
    let compressionQuality: Double
    
    init(
        selectedImages: Binding<[UIImage]>,
        isPresented: Binding<Bool>,
        maxSelections: Int = 5,
        allowsCamera: Bool = true,
        compressionQuality: Double = 0.8
    ) {
        self._selectedImages = selectedImages
        self._isPresented = isPresented
        self.maxSelections = maxSelections
        self.allowsCamera = allowsCamera
        self.compressionQuality = compressionQuality
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header mit Auswahl-Info
                headerView
                
                // Photo Grid oder Empty State
                if !selectedImages.isEmpty {
                    selectedPhotosGrid
                } else {
                    emptyStateView
                }
                
                Spacer()
                
                // Aktion Buttons
                actionButtons
            }
            .navigationTitle("Fotos auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        isPresented = false
                    }
                    .disabled(selectedImages.isEmpty)
                }
            }
            .sheet(isPresented: $viewModel.showingImagePicker) {
                ImagePickerView(
                    sourceType: viewModel.imageSourceType,
                    selectedImage: $viewModel.tempSelectedImage
                )
            }
            .photosPicker(
                isPresented: $viewModel.showingPhotoPicker,
                selection: $viewModel.photoPickerItems,
                maxSelectionCount: maxSelections,
                matching: .images
            )
            .onChange(of: viewModel.photoPickerItems) { _, _ in
                Task {
                    await viewModel.loadSelectedPhotos()
                }
            }
            .onChange(of: viewModel.tempSelectedImage) { _, image in
                if let image = image {
                    addImage(image)
                    viewModel.tempSelectedImage = nil
                }
            }
            .onChange(of: viewModel.loadedImages) { _, images in
                for image in images {
                    addImage(image)
                }
                viewModel.loadedImages.removeAll()
            }
            .alert("Fehler", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(selectedImages.count) von \(maxSelections) ausgewählt")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if viewModel.isLoading {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Lädt...")
                            .font(.caption2)
                    }
                }
            }
            .padding(.horizontal)
            
            // Progress Bar
            ProgressView(value: Double(selectedImages.count), total: Double(maxSelections))
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private var selectedPhotosGrid: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                    selectedPhotoThumbnail(image: image, index: index)
                }
            }
            .padding()
        }
    }
    
    private func selectedPhotoThumbnail(image: UIImage, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipped()
                .cornerRadius(8)
            
            // Remove Button
            Button(action: {
                removeImage(at: index)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.red))
                    .font(.system(size: 20))
            }
            .offset(x: 5, y: -5)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Keine Fotos ausgewählt")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Wähle bis zu \(maxSelections) Fotos aus der Galerie oder nimm neue mit der Kamera auf")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if allowsCamera && viewModel.isCameraAvailable {
                    Button(action: {
                        viewModel.showCameraPicker()
                    }) {
                        Label("Kamera", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedImages.count >= maxSelections)
                }
                
                Button(action: {
                    viewModel.showPhotoPicker()
                }) {
                    Label("Galerie", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(selectedImages.count >= maxSelections)
            }
            
            if !selectedImages.isEmpty {
                Button(action: {
                    clearAllImages()
                }) {
                    Text("Alle entfernen")
                        .foregroundColor(.red)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helper Methods
    
    private func addImage(_ image: UIImage) {
        guard selectedImages.count < maxSelections else { return }
        
        // Komprimierung anwenden
        let compressedImage = compressImage(image, quality: compressionQuality)
        selectedImages.append(compressedImage)
    }
    
    private func removeImage(at index: Int) {
        guard index < selectedImages.count else { return }
        selectedImages.remove(at: index)
    }
    
    private func clearAllImages() {
        selectedImages.removeAll()
    }
    
    private func compressImage(_ image: UIImage, quality: Double) -> UIImage {
        guard let imageData = image.jpegData(compressionQuality: quality),
              let compressedImage = UIImage(data: imageData) else {
            return image
        }
        return compressedImage
    }
}

// MARK: - PhotoPicker ViewModel

@MainActor
class PhotoPickerViewModel: ObservableObject {
    @Published var showingImagePicker = false
    @Published var showingPhotoPicker = false
    @Published var showingError = false
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    @Published var tempSelectedImage: UIImage?
    @Published var photoPickerItems: [PhotosPickerItem] = []
    @Published var loadedImages: [UIImage] = []
    
    var imageSourceType: UIImagePickerController.SourceType = .camera
    
    var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
    
    func showCameraPicker() {
        checkCameraPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.imageSourceType = .camera
                    self?.showingImagePicker = true
                } else {
                    self?.showError("Kamera-Berechtigung erforderlich")
                }
            }
        }
    }
    
    func showPhotoPicker() {
        showingPhotoPicker = true
    }
    
    func loadSelectedPhotos() async {
        guard !photoPickerItems.isEmpty else { return }
        
        isLoading = true
        loadedImages.removeAll()
        
        for item in photoPickerItems {
            do {
                guard let imageData = try await item.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: imageData) else {
                    continue
                }
                loadedImages.append(uiImage)
            } catch {
                showError("Fehler beim Laden eines Fotos: \(error.localizedDescription)")
            }
        }
        
        photoPickerItems.removeAll()
        isLoading = false
    }
    
    private func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

// MARK: - ImagePickerView (Camera Integration)

struct ImagePickerView: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Preview

struct PhotoPicker_Previews: PreviewProvider {
    static var previews: some View {
        PhotoPicker(
            selectedImages: .constant([]),
            isPresented: .constant(true)
        )
    }
} 