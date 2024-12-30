import SwiftUI
import UIKit

@available(iOS 14.0, *)
struct MainViewControllerRepresentable: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> MainViewController {
        let viewController = MainViewController()
        viewController.delegate = context.coordinator
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: MainViewController, context: Context) {
        // Handle updates if needed
    }
    
    class Coordinator: NSObject, MainViewControllerDelegate {
        private var parent: MainViewControllerRepresentable
        weak var viewController: MainViewController?
        
        init(_ parent: MainViewControllerRepresentable) {
            self.parent = parent
            super.init()
        }
        
        func mainViewControllerDidFinish() {
            // Handle completion if needed
        }
    }
}

// Keep the protocol definition
protocol MainViewControllerDelegate: AnyObject {
    func mainViewControllerDidFinish()
} 