import SwiftUI
import PhotosUI
import AVFoundation
import UIKit

/// Erweiterte PhotoPicker-Komponente für Memory-Erstellung - PERFORMANCE OPTIMIZED
/// Unterstützt Multiple Selection, Kamera, Komprimierung und Offline-Storage
struct PhotoPicker: View {
    @StateObject private var viewModel = PhotoPickerViewModel()
    @Binding var selectedImages: [UIImage]
    @Binding var isPresented: Bool
    
    let maxSelections: Int
    let allowsCamera: Bool
    let compressionQuality: Double
    
    // PERFORMANCE: State für UI-Updates reduzieren
    @State private var isViewReady = false
    
    init(
        selectedImages: Binding<[UIImage]>,
        isPresented: Binding<Bool>,
        maxSelections: Int = 5,
        allowsCamera: Bool = true,
        compressionQuality: Double = 0.6 // Reduziert von 0.8 für bessere Performance
    ) {
        self._selectedImages = selectedImages
        self._isPresented = isPresented
        self.maxSelections = maxSelections
        self.allowsCamera = allowsCamera
        self.compressionQuality = compressionQuality
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isViewReady {
                    mainContentView
                } else {
                    loadingView
                }
            }
            .navigationTitle("Fotos auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        cleanupAndDismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        isPresented = false
                    }
                    .disabled(selectedImages.isEmpty)
                }
            }
            .onAppear {
                setupView()
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
                    await viewModel.loadSelectedPhotos(compressionQuality: compressionQuality)
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
                if viewModel.errorMessage.contains("Kamera-Berechtigung") {
                    Button("Einstellungen") {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                    Button("Abbrechen", role: .cancel) { }
                } else {
                    Button("OK") { }
                }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    // MARK: - View Components
    
    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("Wird vorbereitet...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Header mit Auswahl-Info - PERFORMANCE: Conditional rendering
            if !selectedImages.isEmpty || viewModel.isLoading {
                headerView
            }
            
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
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(selectedImages.count) von \(maxSelections) ausgewählt")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // PERFORMANCE: Conditional loading indicator
                if viewModel.isLoading {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Verarbeite...")
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
            // PERFORMANCE: LazyVGrid für bessere Performance bei vielen Bildern
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                    selectedPhotoThumbnail(image: image, index: index)
                }
            }
            .padding()
        }
        .scrollIndicators(.automatic)
    }
    
    private func selectedPhotoThumbnail(image: UIImage, index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipped()
                .cornerRadius(8)
            
            // Remove Button - PERFORMANCE: Optimierte Animation
            Button(action: {
                withAnimation(.easeOut(duration: 0.2)) {
                    removeImage(at: index)
                }
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
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedImages.count >= maxSelections || viewModel.isLoading)
                }
                
                Button(action: {
                    viewModel.showPhotoPicker()
                }) {
                    Label("Galerie", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .disabled(selectedImages.count >= maxSelections || viewModel.isLoading)
            }
            
            // PERFORMANCE: Conditional rendering
            if !selectedImages.isEmpty {
                Button(action: {
                    withAnimation(.easeOut(duration: 0.3)) {
                        clearAllImages()
                    }
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
    
    private func setupView() {
        // PERFORMANCE: Delayed initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.2)) {
                isViewReady = true
            }
        }
    }
    
    private func addImage(_ image: UIImage) {
        guard selectedImages.count < maxSelections else { return }
        
        // PERFORMANCE: Aggressive Komprimierung für Mobile
        let compressedImage = compressImageForMobile(image, quality: compressionQuality)
        selectedImages.append(compressedImage)
    }
    
    private func removeImage(at index: Int) {
        guard index >= 0 && index < selectedImages.count else { return }
        selectedImages.remove(at: index)
    }
    
    private func clearAllImages() {
        selectedImages.removeAll()
        viewModel.loadedImages.removeAll()
    }
    
    private func cleanupAndDismiss() {
        viewModel.cleanup()
        isPresented = false
    }
    
    // PERFORMANCE: Optimierte Image-Komprimierung für Mobile
    private func compressImageForMobile(_ image: UIImage, quality: Double) -> UIImage {
        let maxDimension: CGFloat = 800 // Reduziert für Mobile
        let size = image.size
        
        // Validiere Bildgröße
        guard size.width.isFinite && size.height.isFinite && 
              size.width > 0 && size.height > 0 else {
            return image
        }
        
        let maxCurrentDimension = max(size.width, size.height)
        
        if maxCurrentDimension > maxDimension {
            let ratio = maxDimension / maxCurrentDimension
            let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
            
            // Validiere neue Größe
            guard newSize.width.isFinite && newSize.height.isFinite &&
                  newSize.width > 0 && newSize.height > 0 else {
                return image
            }
            
            // PERFORMANCE: Optimierte Renderer-Konfiguration
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            format.opaque = true
            format.preferredRange = .standard
            
            let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
            let resizedImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
            
            // Zusätzliche JPEG-Komprimierung
            guard let imageData = resizedImage.jpegData(compressionQuality: quality),
                  let finalImage = UIImage(data: imageData) else {
                return resizedImage
            }
            return finalImage
        }
        
        // Auch bei ursprünglicher Größe komprimieren
        guard let imageData = image.jpegData(compressionQuality: quality),
              let compressedImage = UIImage(data: imageData) else {
            return image
        }
        return compressedImage
    }
}

// MARK: - PhotoPicker ViewModel - PERFORMANCE OPTIMIZED

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
    
    // PERFORMANCE: Task-Management
    private var loadingTask: Task<Void, Never>?
    
    var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
    
    deinit {
        // Synchrone Cleanup-Operationen direkt ausführen
        loadingTask?.cancel()
    }
    
    func showCameraPicker() {
        checkCameraPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.imageSourceType = .camera
                    self?.showingImagePicker = true
                } else {
                    self?.showCameraPermissionError()
                }
            }
        }
    }
    
    func showPhotoPicker() {
        showingPhotoPicker = true
    }
    
    // PERFORMANCE: Optimierte Photo-Loading mit TaskGroup
    func loadSelectedPhotos(compressionQuality: Double) async {
        guard !photoPickerItems.isEmpty else { return }
        
        // Cancel previous loading task
        loadingTask?.cancel()
        
        isLoading = true
        loadedImages.removeAll()
        
        loadingTask = Task { @MainActor in
            // PERFORMANCE: Parallel loading mit TaskGroup
            await withTaskGroup(of: UIImage?.self) { group in
                for item in photoPickerItems {
                    group.addTask {
                        await self.loadSinglePhoto(item: item, compressionQuality: compressionQuality)
                    }
                }
                
                for await result in group {
                    if let image = result {
                        loadedImages.append(image)
                    }
                }
            }
            
            photoPickerItems.removeAll()
            isLoading = false
        }
    }
    
    // PERFORMANCE: Optimierte Single Photo Loading
    private func loadSinglePhoto(item: PhotosPickerItem, compressionQuality: Double) async -> UIImage? {
        do {
            // PERFORMANCE: Timeout für Photo-Loading
            return try await withThrowingTaskGroup(of: UIImage?.self) { group in
                group.addTask {
                    guard let imageData = try await item.loadTransferable(type: Data.self),
                          let uiImage = UIImage(data: imageData) else {
                        return nil
                    }
                    
                    // IMMEDIATE Komprimierung für bessere Performance
                    return await self.compressImageImmediately(uiImage, quality: compressionQuality)
                }
                
                group.addTask {
                    try await Task.sleep(for: .seconds(10)) // Timeout
                    throw CancellationError()
                }
                
                let result = try await group.next()
                group.cancelAll()
                return result ?? nil
            }
            
        } catch {
            if !(error is CancellationError) {
                print("⚠️ PhotoPicker: Einzelfoto-Laden fehlgeschlagen: \(error)")
            }
            return nil
        }
    }
    
    // PERFORMANCE: Sofortige Komprimierung
    private func compressImageImmediately(_ image: UIImage, quality: Double) async -> UIImage {
        let maxDimension: CGFloat = 600 // Sehr reduziert für Mobile
        let size = image.size
        
        guard size.width > maxDimension || size.height > maxDimension else {
            // Nur JPEG-Komprimierung anwenden
            guard let imageData = image.jpegData(compressionQuality: quality),
                  let compressedImage = UIImage(data: imageData) else {
                return image
            }
            return compressedImage
        }
        
        let maxCurrentDimension = max(size.width, size.height)
        let ratio = maxDimension / maxCurrentDimension
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        // PERFORMANCE: Sehr schnelle Resize-Operation
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        format.preferredRange = .standard
        
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        // Zusätzliche JPEG-Komprimierung
        guard let imageData = resizedImage.jpegData(compressionQuality: quality),
              let finalImage = UIImage(data: imageData) else {
            return resizedImage
        }
        return finalImage
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
    
    private func showCameraPermissionError() {
        showError("Kamera-Berechtigung wurde verweigert. Bitte aktivieren Sie diese in den Einstellungen, um Fotos aufnehmen zu können.")
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
    
    // PERFORMANCE: Resource Cleanup
    @MainActor
    func cleanup() {
        loadingTask?.cancel()
        loadingTask = nil
        photoPickerItems.removeAll()
        loadedImages.removeAll()
        tempSelectedImage = nil
    }
}

// MARK: - ImagePickerView (Camera Integration) - PERFORMANCE OPTIMIZED

struct ImagePickerView: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        
        // PERFORMANCE: Optimierte Kamera-Einstellungen
        if sourceType == .camera {
            picker.cameraDevice = .rear
            picker.cameraCaptureMode = .photo
        }
        
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
            // PERFORMANCE: Prefer edited image for better quality/size ratio
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