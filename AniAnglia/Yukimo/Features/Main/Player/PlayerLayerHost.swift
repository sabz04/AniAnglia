//
//  PlayerLayerHost.swift
//  Minimal SwiftUI wrapper around an AVPlayerLayer — no native controls.
//

import SwiftUI
import AVKit
import AVFoundation

final class YukimoPlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    var pipController: AVPictureInPictureController?
}

struct PlayerLayerHost: UIViewRepresentable {
    let player: AVPlayer
    /// Called once the underlying view has been instantiated; receives a PiP
    /// controller bound to this layer (`nil` if the device doesn't support PiP).
    let onPiPReady: (AVPictureInPictureController?) -> Void

    func makeUIView(context: Context) -> YukimoPlayerLayerView {
        let v = YukimoPlayerLayerView()
        v.backgroundColor = .black
        v.playerLayer.player = player
        v.playerLayer.videoGravity = .resizeAspect

        if AVPictureInPictureController.isPictureInPictureSupported() {
            let pip = AVPictureInPictureController(playerLayer: v.playerLayer)
            pip?.canStartPictureInPictureAutomaticallyFromInline = true
            v.pipController = pip
        }
        let ctrl = v.pipController
        DispatchQueue.main.async { onPiPReady(ctrl) }
        return v
    }

    func updateUIView(_ uiView: YukimoPlayerLayerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }
}
