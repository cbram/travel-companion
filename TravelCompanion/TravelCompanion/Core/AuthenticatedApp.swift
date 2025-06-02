import SwiftUI

/// Haupt-Wrapper für die App, der die Authentifizierung verwaltet
struct AuthenticatedApp: View {
    @StateObject private var authState = AuthenticationState.shared
    @EnvironmentObject private var userManager: UserManager
    
    var body: some View {
        Group {
            if authState.isLoading {
                // Loading Screen
                LoadingView()
            } else if authState.needsUserSelection {
                // Benutzerauswahl/Registrierung
                UserSelectionView()
                    .environmentObject(authState)
            } else if authState.isAuthenticated {
                // Hauptapp
                ContentView()
            } else {
                // Fallback - sollte nicht auftreten
                ErrorView(message: "Unbekannter Authentifizierungsstatus")
            }
        }
        .onAppear {
            authState.checkAuthenticationStatus()
        }
    }
}

/// Loading Screen während der Authentifizierungs-Überprüfung
struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            // App Icon oder Logo
            Image(systemName: "airplane.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            Text("Travel Companion")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Lade Benutzerdaten...")
                .font(.body)
                .foregroundColor(.secondary)
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            isAnimating = true
        }
    }
}

/// Fehler-View für unerwartete Zustände
struct ErrorView: View {
    let message: String
    @StateObject private var authState = AuthenticationState.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Oops!")
                .font(.title)
                .fontWeight(.bold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Erneut versuchen") {
                authState.checkAuthenticationStatus()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Preview
struct AuthenticatedApp_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Loading State
            LoadingView()
                .previewDisplayName("Loading")
            
            // Error State
            ErrorView(message: "Beispiel-Fehlermeldung für die Vorschau")
                .previewDisplayName("Error")
            
            // Main App
            AuthenticatedApp()
                .environmentObject(UserManager.shared)
                .previewDisplayName("Authenticated App")
        }
    }
} 