import SwiftUI

/// View für die Erstellung neuer Reisen mit schönem Form-Design
struct TripCreationView: View {
    @StateObject private var viewModel: TripCreationViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: FocusField?
    
    let user: User
    
    // MARK: - Initialization
    init(user: User) {
        self.user = user
        self._viewModel = StateObject(wrappedValue: TripCreationViewModel(user: user))
    }
    
    // MARK: - FocusField Enum
    enum FocusField {
        case title, description
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    formSection
                    saveButtonSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Neue Reise")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        Task {
                            if await viewModel.createTrip() != nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canSave)
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("Fehler", isPresented: $viewModel.showingError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "suitcase.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Neue Reise erstellen")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("Erstelle eine neue Reise und beginne deine Abenteuer zu dokumentieren.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 16)
    }
    
    // MARK: - Form Section
    private var formSection: some View {
        VStack(spacing: 20) {
            // Titel Eingabe
            VStack(alignment: .leading, spacing: 8) {
                Label("Titel", systemImage: "textformat")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("z.B. Italien Rundreise", text: $viewModel.title)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .title)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .description
                    }
                
                if let validationMessage = viewModel.getTitleValidationMessage() {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            // Beschreibung Eingabe
            VStack(alignment: .leading, spacing: 8) {
                Label("Beschreibung", systemImage: "text.alignleft")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("Optionale Beschreibung deiner Reise...", text: $viewModel.description, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
                    .focused($focusedField, equals: .description)
            }
            
            // Startdatum Auswahl
            VStack(alignment: .leading, spacing: 8) {
                Label("Startdatum", systemImage: "calendar")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                DatePicker(
                    "Wann beginnt deine Reise?",
                    selection: $viewModel.startDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemBackground))
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Save Button Section
    private var saveButtonSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                Task {
                    if await viewModel.createTrip() != nil {
                        dismiss()
                    }
                }
            }) {
                HStack(spacing: 12) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    
                    Text(viewModel.isLoading ? "Wird erstellt..." : "Reise erstellen")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            viewModel.canSave 
                            ? Color.blue 
                            : Color.gray.opacity(0.3)
                        )
                )
                .foregroundColor(.white)
            }
            .disabled(!viewModel.canSave)
            
            // Hilfetext
            Text("Die neue Reise wird automatisch als aktive Reise ausgewählt.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Preview
struct TripCreationView_Previews: PreviewProvider {
    static func createPreviewUser() -> User {
        let context = PersistenceController.preview.container.viewContext
        let user = User(context: context)
        user.id = UUID()
        user.email = "test@example.com"
        user.displayName = "Test User"
        return user
    }
    
    static var previews: some View {
        let user = createPreviewUser()
        
        Group {
            TripCreationView(user: user)
                .preferredColorScheme(.light)
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            
            TripCreationView(user: user)
                .preferredColorScheme(.dark)
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
} 