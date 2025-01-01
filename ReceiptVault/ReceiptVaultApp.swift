//
//  ReceiptVaultApp.swift
//  ReceiptVault
//
//  Created by Benjamin lang on 22/12/2024.
//

import SwiftUI
import GoogleSignIn

@main
struct ReceiptVaultApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        print("\n=== App Initialization ===")
        // Initialize LocalFileManager
        _ = LocalFileManager.shared
        print("✓ App initialization complete")
    }
    
    var body: some Scene {
        WindowGroup {
            TabBarControllerRepresentable()
                .ignoresSafeArea()
                .onAppear {
                    // Ensure we're using the main thread for UI
                    DispatchQueue.main.async {
                        UIApplication.shared.windows.first?.makeKeyAndVisible()
                    }
                }
        }
    }
}

struct TabBarControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UITabBarController {
        let tabBarController = UITabBarController()
        
        // Receipts Tab
        let receiptsVC = ReceiptsViewController()
        let receiptsNav = UINavigationController(rootViewController: receiptsVC)
        receiptsNav.tabBarItem = UITabBarItem(
            title: "קבלות",
            image: UIImage(systemName: "doc.text"),
            selectedImage: UIImage(systemName: "doc.text.fill")
        )
        
        // Scan Tab
        let scanVC = MainViewController()
        let scanNav = UINavigationController(rootViewController: scanVC)
        scanNav.tabBarItem = UITabBarItem(
            title: "סריקה",
            image: UIImage(systemName: "camera"),
            selectedImage: UIImage(systemName: "camera.fill")
        )
        
        // Settings Tab
        let settingsVC = SettingsViewController()
        let settingsNav = UINavigationController(rootViewController: settingsVC)
        settingsNav.tabBarItem = UITabBarItem(
            title: "הגדרות",
            image: UIImage(systemName: "gear"),
            selectedImage: UIImage(systemName: "gear.fill")
        )
        
        tabBarController.viewControllers = [receiptsNav, scanNav, settingsNav]
        tabBarController.selectedIndex = 1  // Set Scan tab as default
        
        return tabBarController
    }
    
    func updateUIViewController(_ uiViewController: UITabBarController, context: Context) {}
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Google Sign In
        let clientID = "634293998454-apeckjpcu9tcgqg2t6td9jne5d18187h.apps.googleusercontent.com"
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Try to restore previous sign-in
        Task {
            do {
                let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
                // Check if we need to refresh the token
                if let expirationDate = user.accessToken.expirationDate,
                   expirationDate.compare(Date()) == .orderedAscending {
                    try await user.refreshTokensIfNeeded()
                }
                print("Successfully restored Google Sign In")
                
                // Create root folder if needed
                GoogleDriveService.shared.authenticate(from: UIApplication.shared.windows.first?.rootViewController ?? UIViewController()) { result in
                    switch result {
                    case .success:
                        print("Successfully authenticated with Google Drive")
                    case .failure(let error):
                        print("Failed to authenticate with Google Drive: \(error.localizedDescription)")
                    }
                }
            } catch {
                print("No previous Google Sign In found or error: \(error.localizedDescription)")
            }
        }
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}
