//
//  Toast.swift

//
//

import UIKit

@objcMembers
public class Toast :NSObject{
    
    static let sharedInstance = Toast()
    static var isShow = false
    private override init() {}
    
    static var currentToastView : ToastView?
  
    
    @objc public static func show(message: String, duration: TimeInterval = 1.0,aParentView:UIView? = nil) {
        performTaskOnMainThread {
            guard let window = UIApplication.shared.windows.filter({ $0.isKeyWindow }).first else { return }
            currentToastView?.removeFromSuperview()
            
            // Create toast view
            let toastView = ToastView(message: message)
            currentToastView = toastView
            if let aParentViewA = aParentView{
                aParentViewA.addSubview(toastView)
                        
                // Add constraints
                toastView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    toastView.centerXAnchor.constraint(equalTo: aParentViewA.centerXAnchor),
                    toastView.centerYAnchor.constraint(equalTo: aParentViewA.centerYAnchor)
                ])
            }
            else{
                window.addSubview(toastView)
                        
                // Add constraints
                toastView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    toastView.centerXAnchor.constraint(equalTo: window.centerXAnchor),
                    toastView.centerYAnchor.constraint(equalTo: window.centerYAnchor)
                ])
            }
          
            
            // Animate the view
            toastView.alpha = 0
            toastView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
                toastView.alpha = 1
                toastView.transform = .identity
            }, completion: { _ in
                UIView.animate(withDuration: 0.2, delay: duration, options: [], animations: {
                    toastView.alpha = 0
                    toastView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                }, completion: { _ in
                    toastView.removeFromSuperview()
                    isShow = false
                })
            })
        }
    }
}


public class ToastView: UIView {

    private let messageLabel = UILabel()
    private let containerView = UIView()

    
    public override func layoutSubviews() {
           super.layoutSubviews()
           
           // Update container view width constraint to fit within the screen
           if let superview = superview {
               let maxWidth = superview.bounds.width - 40 // Adjust the margin as needed
               containerView.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth).isActive = true
           }
       }
    
    
    public init(message: String) {
        super.init(frame: .zero)

        // Configure message label
        messageLabel.text = message
        messageLabel.textColor = .white
        messageLabel.font = UIFont.systemFont(ofSize: 16)
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center

        // Configure container view
//        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        containerView.backgroundColor = .init(white: 0, alpha: 0.8)
        containerView.layer.cornerRadius = 8
        containerView.clipsToBounds = true

        // Add subviews
        addSubview(containerView)
        containerView.addSubview(messageLabel)

        // Add constraints
        containerView.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            messageLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            messageLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12)
        ])

        // Animate the view
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
            self.alpha = 1
            self.transform = .identity
        }, completion: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func dismiss() {
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        }, completion: { _ in
            self.removeFromSuperview()
        })
    }
}
