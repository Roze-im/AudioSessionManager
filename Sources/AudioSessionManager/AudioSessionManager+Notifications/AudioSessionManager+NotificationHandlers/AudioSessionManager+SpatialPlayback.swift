//
//  AudioSessionManager+SpatialPlayback.swift
//  AudioRecorder
//
//  Created by Alexis Barat on 18/04/2023.
//

import Foundation
import AVFoundation

extension AudioSessionManager {
    @objc func handleSpatialPlaybackCapabilitiesChangedNotification(notification: Notification) {
        guard let payload: NotificationPaylod.SpatialPlayback = .init(notification) else {
            logger?(.error, "Failed to cast spatial playback notification into payload.")
            return
        }

        logger?(.debug, "handleSpatialPlaybackCapabilityNotification \(payload)")
    }
}

extension AudioSessionManager.NotificationPaylod {
    public struct SpatialPlayback {

        public var enabled: Bool

        init?(_ notification: Notification) {
            guard   notification.name == AVAudioSession.spatialPlaybackCapabilitiesChangedNotification,
                    let userInfo = notification.userInfo,
                    let enabled: Bool = userInfo[AVAudioSessionSpatialAudioEnabledKey] as? Bool
            else { return nil }

            self.enabled = enabled
        }
    }
}
