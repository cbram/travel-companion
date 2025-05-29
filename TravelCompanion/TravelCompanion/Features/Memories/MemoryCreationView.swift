import SwiftUI
import PhotosUI
import CoreLocation

struct MemoryCreationView: View {
    @StateObject private var viewModel: MemoryCreationViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let trip: Trip
    let user: User
    
    init(trip: Trip, user: User) {
        self.trip = trip
        self.user = user
        self._viewModel = StateObject(wrappedValue: MemoryCreationViewModel(trip: trip, user: user))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection
                    
                    // Form Content
                    VStack(spacing: 16) {
                        // Titel Input
                        titleSection
                        
                        // Beschreibung Input
                        descriptionSection
                        
                        // GPS Koordinaten
                        locationSection
                        
                        // Foto Sektion
                        photoSection
                        
                        // Speichern Button
                        saveButton
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Neue Erinnerung")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingImagePicker) {
                ImagePickerView(
                    sourceType: viewModel.imageSourceType,
                    selectedImage: $viewModel.selectedImage
                )
            }
            .photosPicker(
                isPresented: $viewModel.showingPhotoPicker,
                selection: $viewModel.photoPickerItem,
                matching: .images
            )
            .onChange(of: viewModel.photoPickerItem) { _, _ in
                viewModel.loadSelectedPhoto()
            }
            .alert("Fehler", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert("Erfolg", isPresented: $viewModel.showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Erinnerung wurde erfolgreich gespeichert!")
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Neue Erinnerung erstellen")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Halte deine Reisemomente fest")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top)
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Titel", systemImage: "textformat")
                .font(.headline)
                .foregroundColor(.primary)
            
            TextField("Was hast du erlebt?", text: $viewModel.title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .submitLabel(.next)
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Beschreibung", systemImage: "text.alignleft")
                .font(.headline)
                .foregroundColor(.primary)
            
            TextField("Erzähle mehr über diesen Moment...", 
                     text: $viewModel.content, 
                     axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(3...6)
        }
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Standort", systemImage: "location.fill")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let location = viewModel.currentLocation {
                        Text("📍 \(location.coordinate.latitude, specifier: "%.6f"), \(location.coordinate.longitude, specifier: "%.6f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Genauigkeit: ±\(Int(location.horizontalAccuracy))m")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("GPS-Position wird ermittelt...")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                Button("Aktualisieren") {
                    viewModel.updateLocation()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Foto", systemImage: "photo")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Ausgewähltes Foto anzeigen
            if let image = viewModel.selectedImage {
                selectedPhotoView(image: image)
            }
            
            // Foto-Auswahl Buttons
            photoSelectionButtons
        }
    }
    
    private func selectedPhotoView(image: UIImage) -> some View {
        VStack(spacing: 12) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxHeight: 200)
                .clipped()
                .cornerRadius(12)
            
            Button(action: {
                viewModel.removeSelectedImage()
            }) {
                Label("Foto entfernen", systemImage: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var photoSelectionButtons: some View {
        HStack(spacing: 12) {
            Button(action: {
                viewModel.showCameraPicker()
            }) {
                Label("Kamera", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.isCameraAvailable)
            
            Button(action: {
                viewModel.showPhotoPicker()
            }) {
                Label("Galerie", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var saveButton: some View {
        Button(action: {
            Task {
                await viewModel.saveMemory()
            }
        }) {
            HStack {
                if viewModel.isSaving {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Speichern...")
                } else {
                    Image(systemName: "square.and.arrow.down")
                    Text("Erinnerung speichern")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.canSave ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!viewModel.canSave || viewModel.isSaving)
        .padding(.top)
    }
}

// MARK: - Preview

struct MemoryCreationView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let user = User(context: context)
        user.id = UUID()
        user.email = "test@example.com"
        user.displayName = "Test User"
        
        let trip = Trip(context: context)
        trip.id = UUID()
        trip.title = "Test Trip"
        trip.startDate = Date()
        trip.owner = user
        
        return MemoryCreationView(trip: trip, user: user)
            .environment(\.managedObjectContext, context)
    }
} 