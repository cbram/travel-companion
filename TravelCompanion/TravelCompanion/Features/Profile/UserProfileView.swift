import SwiftUI

/// Detaillierte Ansicht für das Benutzerprofil mit Bearbeitungsmöglichkeiten
struct UserProfileView: View {
    @EnvironmentObject private var userManager: UserManager
    @State private var isEditing = false
    @State private var showingUserSelection = false
    @State private var showingDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    private var currentUser: User? {
        userManager.currentUser
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if let user = currentUser {
                        // User Header
                        UserHeaderView(user: user)
                        
                        // User Statistics
                        UserStatsView(user: user)
                        
                        // Profile Actions
                        ProfileActionsView(
                            onEdit: { isEditing = true },
                            onSwitchUser: { showingUserSelection = true },
                            onDeactivate: { showingDeleteConfirmation = true }
                        )
                    } else {
                        // Kein User angemeldet
                        NoUserView {
                            showingUserSelection = true
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if currentUser != nil {
                        Button("Bearbeiten") {
                            isEditing = true
                        }
                    }
                }
            }
            .sheet(isPresented: $isEditing) {
                if let user = currentUser {
                    EditUserProfileView(user: user)
                }
            }
            .sheet(isPresented: $showingUserSelection) {
                UserSelectionView()
            }
            .alert("Benutzer deaktivieren", isPresented: $showingDeleteConfirmation) {
                Button("Abbrechen", role: .cancel) { }
                Button("Deaktivieren", role: .destructive) {
                    if let user = currentUser {
                        _ = userManager.deactivateUser(user)
                    }
                }
            } message: {
                Text("Möchtest du diesen Benutzer wirklich deaktivieren? Alle Daten bleiben erhalten, aber der Benutzer wird aus der Auswahl entfernt.")
            }
        }
    }
}

/// Header-Bereich mit Avatar und Grundinformationen
struct UserHeaderView: View {
    let user: User
    
    var body: some View {
        VStack(spacing: 16) {
            // Avatar
            AsyncImage(url: URL(string: user.avatarURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.gray)
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            
            // Name und Email
            VStack(spacing: 4) {
                Text(user.displayName ?? "Unbekannt")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(user.email ?? "")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            // Mitglied seit
            Text("Mitglied seit \(user.formattedCreatedAt)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

/// Statistiken des Benutzers
struct UserStatsView: View {
    let user: User
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Statistiken")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Reisen",
                    value: "\(user.tripsCount)",
                    icon: "suitcase.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "Erinnerungen",
                    value: "\(user.memoriesCount)",
                    icon: "heart.fill",
                    color: .red
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

/// Einzelne Statistik-Karte
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

/// Profil-Aktionen
struct ProfileActionsView: View {
    let onEdit: () -> Void
    let onSwitchUser: () -> Void
    let onDeactivate: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Aktionen")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                ProfileActionButton(
                    title: "Profil bearbeiten",
                    icon: "pencil",
                    color: .blue,
                    action: onEdit
                )
                
                ProfileActionButton(
                    title: "Benutzer wechseln",
                    icon: "person.2.circle",
                    color: .orange,
                    action: onSwitchUser
                )
                
                ProfileActionButton(
                    title: "Benutzer deaktivieren",
                    icon: "trash",
                    color: .red,
                    action: onDeactivate
                )
            }
        }
    }
}

/// Aktions-Button
struct ProfileActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Ansicht wenn kein User angemeldet ist
struct NoUserView: View {
    let onGetStarted: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("Kein Benutzer angemeldet")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Melde dich an oder erstelle einen neuen Benutzer um Travel Companion zu verwenden")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onGetStarted) {
                Text("Loslegen")
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

// MARK: - Preview
struct UserProfileView_Previews: PreviewProvider {
    static var previews: some View {
        UserProfileView()
            .environmentObject(UserManager.shared)
    }
} 