import SwiftUI
import PhotosUI
import CoreLocation

struct MemoryCreationView: View {
    @StateObject private var viewModel = MemoryCreationViewModel()
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFieldFocused: Bool
    @FocusState private var descriptionFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header
                    headerSection
                    
                    // Form Content
                    VStack(spacing: 16) {
                        // Trip Info (falls vorhanden)
                        if let trip = viewModel.trip {
                            tripInfoSection(for: trip)
                        }
                        
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
            .dismissKeyboardOnTap()
            .customKeyboardToolbar {
                HStack {
                    Spacer()
                    Button("Fertig") {
                        hideKeyboard()
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .sheet(isPresented: $viewModel.showingImagePicker) {
                ImagePickerView(
                    sourceType: viewModel.imageSourceType,
                    selectedImage: $viewModel.selectedImage
                )
                .interactiveDismissDisabled(viewModel.isSaving)
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
                Text("Memory wurde erfolgreich gespeichert!")
            }
            .alert("Keine aktive Reise", isPresented: $viewModel.showingNoTripAlert) {
                Button("OK") { }
            } message: {
                Text("Bitte erstelle zuerst eine Reise oder setze eine Reise als aktiv.")
            }
        }
        .onAppear {
            viewModel.checkActiveTrip()
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
    
    private func tripInfoSection(for trip: Trip) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "suitcase.fill")
                    .foregroundColor(.blue)
                Text("Für: \(trip.title ?? "Aktuelle Reise")")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text("AKTIV")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
            
            if let description = trip.tripDescription, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Titel", systemImage: "textformat")
                .font(.headline)
                .foregroundColor(.primary)
            
            TextField("Was hast du erlebt?", text: $viewModel.title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .submitLabel(.next)
                .focused($titleFieldFocused)
                .onSubmit {
                    descriptionFieldFocused = true
                }
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
                .focused($descriptionFieldFocused)
                .submitLabel(.done)
                .onSubmit {
                    hideKeyboard()
                }
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
                        Text("📍 \(location.formattedCoordinates)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Genauigkeit: \(location.formattedAccuracy)")
                            .font(.caption2)
                            .foregroundColor(location.horizontalAccuracy >= 0 ? .secondary : .orange)
                    } else {
                        Text("GPS-Position wird ermittelt...")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                Button("Aktualisieren") {
                    if !viewModel.isUpdatingLocation {
                        viewModel.updateLocation()
                    }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .disabled(viewModel.isUpdatingLocation)
                .overlay(
                    Group {
                        if viewModel.isUpdatingLocation {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }
                )
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Foto", systemImage: "camera")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let selectedImage = viewModel.selectedImage {
                // Selected Image Preview
                VStack(spacing: 8) {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                        .cornerRadius(12)
                    
                    Button("Foto entfernen") {
                        viewModel.removeSelectedImage()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            } else {
                // Photo Selection Buttons
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.showCameraPicker()
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                            Text("Kamera")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .disabled(!viewModel.isCameraAvailable)
                    
                    Button(action: {
                        viewModel.showPhotoPicker()
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.fill")
                                .font(.title2)
                            Text("Galerie")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
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
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                }
                Text(viewModel.isSaving ? "Speichert..." : "Memory speichern")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.canSave ? Color.blue : Color.gray)
            .cornerRadius(12)
        }
        .disabled(!viewModel.canSave || viewModel.isSaving)
        .padding(.top)
    }
    
    // MARK: - Helper Methods
    
    private func hideKeyboard() {
        titleFieldFocused = false
        descriptionFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Preview
struct MemoryCreationView_Previews: PreviewProvider {
    static var previews: some View {
        // Create sample context with data for preview
        let previewContext = PersistenceController.preview.container.viewContext
        
        // Ensure sample data exists
        let _ = SampleDataCreator.createSampleData(in: previewContext)
        
        return MemoryCreationView()
            .environment(\.managedObjectContext, previewContext)
    }
} 