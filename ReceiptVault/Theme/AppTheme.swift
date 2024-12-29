import UIKit

enum AppTheme {
    static let primaryColor = UIColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1)  // iOS Blue
    static let secondaryColor = UIColor(red: 88/255, green: 86/255, blue: 214/255, alpha: 1)  // iOS Purple
    static let backgroundColor = UIColor.systemBackground
    static let cardBackgroundColor = UIColor.secondarySystemBackground
    static let accentColor = UIColor(red: 52/255, green: 199/255, blue: 89/255, alpha: 1)  // iOS Green
    
    static let cornerRadius: CGFloat = 12
    static let padding: CGFloat = 16
    static let smallPadding: CGFloat = 8
    
    static let shadowOpacity: Float = 0.1
    static let shadowRadius: CGFloat = 4
    static let shadowOffset = CGSize(width: 0, height: 2)
    
    static func applyShadow(to view: UIView) {
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = shadowOpacity
        view.layer.shadowRadius = shadowRadius
        view.layer.shadowOffset = shadowOffset
    }
    
    static func styleButton(_ button: UIButton) {
        button.backgroundColor = primaryColor
        button.tintColor = .white
        button.layer.cornerRadius = cornerRadius
        applyShadow(to: button)
    }
    
    static func styleCard(_ view: UIView) {
        view.backgroundColor = cardBackgroundColor
        view.layer.cornerRadius = cornerRadius
        applyShadow(to: view)
    }
} 