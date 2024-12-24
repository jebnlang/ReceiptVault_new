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
    
    var body: some Scene {
        WindowGroup {
            MainViewControllerRepresentable()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}
