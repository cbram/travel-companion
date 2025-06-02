import SwiftUI

/// View für die Erstellung neuer Reisen
/// Bietet ein einfaches Formular mit Validation und automatischer Navigation
struct TripCreationView: View {
    @StateObject private var viewModel = TripCreationViewModel()
    @EnvironmentObject private var tripManager: TripManager
    @EnvironmentObject private var userManager: UserManager
    @Environment(\.dismiss) private var dismiss
    
    // Neue State für User-Erstellung
    @State private var showingUserCreation = false
    
    var body: some View {
        NavigationView {
            Form {
                // Titel Section
                Section("Titel der Reise") {
                    TextField("z.B. Italien Rundreise", text: $viewModel.title)
                        .textFieldStyle(.roundedBorder)
                }
                .headerProminence(.increased)
                
                // Beschreibung Section
                Section("Beschreibung (Optional)") {
                    TextEditor(text: $viewModel.description)
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                
                // Startdatum Section
                Section("Startdatum") {
                    DatePicker(
                        "Wann beginnt Ihre Reise?",
                        selection: $viewModel.startDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)
                }
                
                // Zusätzliche Optionen
                Section("Optionen") {
                    Toggle("Sofort als aktive Reise setzen", isOn: $viewModel.setAsActive)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
                
                // Vorschau Section
                if !viewModel.title.isEmpty {
                    Section("Vorschau") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "suitcase.fill")
                                    .foregroundColor(.blue)
                                Text(viewModel.title)
                                    .font(.headline)
                                Spacer()
                            }
                            
                            if !viewModel.description.isEmpty {
                                Text(viewModel.description)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)
                            }
                            
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.secondary)
                                Text("Start: \(viewModel.startDate, formatter: DateFormatter.mediumDate)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Neue Reise")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Erstellen") {
                        viewModel.createTrip(using: tripManager) { result in
                            switch result {
                            case .success:
                                dismiss()
                            case .noUserAvailable:
                                showingUserCreation = true
                            case .userValidationFailed, .saveFailed, .validationFailed:
                                // Andere Fehler werden durch das ViewModel behandelt
                                break
                            }
                        }
                    }
                    .disabled(!viewModel.isValid)
                    .fontWeight(.semibold)
                }
            }
            .alert("Fehler", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .sheet(isPresented: $showingUserCreation) {
                UserCreationView {
                    // Nach User-Erstellung automatisch Trip erstellen
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        viewModel.createTrip(using: tripManager) { result in
                            if case .success = result {
                                dismiss()
                            }
                        }
                    }
                }
                .environmentObject(userManager)
            }
            .disabled(viewModel.isCreating)
            .overlay(
                // Loading Overlay
                viewModel.isCreating ? 
                Color.black.opacity(0.3)
                    .overlay(
                        ProgressView("Reise wird erstellt...")
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                    )
                    .ignoresSafeArea()
                : nil
            )
        }
    }
}

/// ViewModel für TripCreationView
/// Verwaltet Form-State, Validation und Trip-Erstellung
class TripCreationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var title = ""
    @Published var description = ""
    @Published var startDate = Date()
    @Published var setAsActive = true
    @Published var isCreating = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    // MARK: - Computed Properties
    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Trip Creation
    func createTrip(using tripManager: TripManager, completion: @escaping (TripCreationResult) -> Void) {
        guard isValid else {
            showError(message: "Bitte geben Sie einen Titel für die Reise ein.")
            completion(.validationFailed("Titel fehlt"))
            return
        }
        
        isCreating = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            let trimmedDescription = self.description.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalDescription = trimmedDescription.isEmpty ? nil : trimmedDescription
            
            let result = tripManager.createTripWithResult(
                title: self.title,
                description: finalDescription,
                startDate: self.startDate
            )
            
            switch result {
            case .success(let trip):
                // Als aktive Reise setzen wenn gewünscht
                if self.setAsActive {
                    tripManager.setActiveTrip(trip)
                }
                
                self.isCreating = false
                completion(result)
                print("✅ TripCreationView: Reise erfolgreich erstellt: \(self.title)")
                
            case .noUserAvailable:
                // Kein Fehler anzeigen, stattdessen UserCreationView öffnen
                self.isCreating = false
                completion(result)
                print("📝 TripCreationView: Kein User vorhanden - öffne User-Erstellung")
                
            case .userValidationFailed:
                self.showError(message: "Benutzer-Validierung fehlgeschlagen. Bitte versuche es erneut.")
                self.isCreating = false
                completion(result)
                
            case .saveFailed(let errorMessage):
                self.showError(message: "Fehler beim Speichern: \(errorMessage)")
                self.isCreating = false
                completion(result)
                
            case .validationFailed(let errorMessage):
                self.showError(message: "Validierung fehlgeschlagen: \(errorMessage)")
                self.isCreating = false
                completion(result)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Date Formatter Extension
extension DateFormatter {
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
}

// MARK: - Preview
struct TripCreationView_Previews: PreviewProvider {
    static var previews: some View {
        TripCreationView()
            .environmentObject(TripManager.shared)
            .environmentObject(UserManager.shared)
    }
} 