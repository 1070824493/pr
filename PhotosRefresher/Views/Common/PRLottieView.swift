//
//  LLLottieView.swift

//
//  Created by R on 2025/4/15.
//

import SwiftUI
import Lottie

struct PRLottieView: UIViewRepresentable {
    let animationName: String
    let loopMode: LottieLoopMode
    let speed: CGFloat
    let bundle: Bundle?
    var playCompleted: LottieCompletionBlock?

    private let animationView = LottieAnimationView()
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        
        let bundle = bundle ?? .main
        let searchPath = animationName.components(separatedBy: "/").first ?? ""
        animationView.imageProvider = BundleImageProvider(
            bundle: bundle,
            searchPath: searchPath
        )
        
        let animation = LottieAnimation.named(animationName, bundle: bundle)
        animationView.animation = animation
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = loopMode
        animationView.animationSpeed = speed
        animationView.play(completion: playCompleted)

        animationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(animationView)

        NSLayoutConstraint.activate([
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor),
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor),
            animationView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            animationView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

