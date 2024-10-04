//
//  AudioSessionManager+ProximitySensor.swift
//  AudioRecorder
//
//  Created by Alexis Barat on 18/04/2023.
//

import Foundation
import UIKit

extension AudioSessionManager {
    @objc func handleProximitySensorNotification(notification: Notification) {
        logger?(.debug, "handleProximitySensorNotification \(notification)")
        do {
            try computeAndUpdatePortOverride(logger: logger)
            let proximityState: Bool = UIDevice.current.proximityState

            switch state {
            case .playing(_, let it, let paused):
                if !paused, !proximityState {
                    // If proximity sensor becomes false while playing an audio, we pause it
                    _ = pausePlayingItem(it)
                }
            default:
                assertionFailure("We're not supposed to observe proximity sensor when we're not in playing state")
            }
        } catch {
            self.state = .error(sessionConfiguration: state.sessionConfiguration, error: error)
        }
    }
}
