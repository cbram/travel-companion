import SwiftUI

/// View für die Auswahl oder Erstellung von Benutzern
struct UserSelectionView: View {
    @EnvironmentObject private var userManager: UserManager
    @EnvironmentObject private var authenticationState: AuthenticationState
    @State private var showingRegistration = false
    @State private var selectedUser: User?
    @Environment(\.dismiss) private var dismiss
    
    private var activeUsers: [User] {
        userManager.getAllActiveUsers()
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.2.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Benutzer auswählen")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Wähle einen bestehenden Benutzer oder erstelle einen neuen")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                if activeUsers.isEmpty {
                    // Keine Benutzer vorhanden
                    VStack(spacing: 16) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("Noch keine Benutzer vorhanden")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Erstelle deinen ersten Benutzer um zu beginnen")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    Spacer()
                } else {
                    // Bestehende Benutzer anzeigen
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(activeUsers, id: \.id) { user in
                                UserRowView(
                                    user: user,
                                    isSelected: selectedUser?.id == user.id
                                ) {
                                    selectedUser = user
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Ausgewählten Benutzer verwenden Button
                    if let selectedUser = selectedUser {
                        Button(action: {
                            authenticationState.signIn(user: selectedUser)
                            dismiss()
                        }) {
                            Text("Als \(selectedUser.displayName ?? "Unbekannt") anmelden")
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Neuen Benutzer erstellen Button
                Button(action: {
                    showingRegistration = true
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Neuen Benutzer erstellen")
                    }
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Benutzer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Schließen Button nur wenn andere Benutzer vorhanden sind
                if !activeUsers.isEmpty && userManager.currentUser != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Schließen") {
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingRegistration) {
                UserRegistrationView()
                    .environmentObject(authenticationState)
            }
        }
    }
}

/// Einzelne Benutzer-Zeile für die Auswahl
struct UserRowView: View {
    let user: User
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                AsyncImage(url: URL(string: user.avatarURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName ?? "Unbekannt")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(user.email ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Erstellt: \(user.formattedCreatedAt)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(user.tripsCount) Reisen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Auswahl Indikator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
struct UserSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        UserSelectionView()
            .environmentObject(UserManager.shared)
            .environmentObject(AuthenticationState.shared)
    }
} 