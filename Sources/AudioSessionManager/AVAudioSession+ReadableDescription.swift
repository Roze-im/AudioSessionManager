//
//  AVAudioSession+ReadableDescription.swift
//  AudioRecorder
//
//  Created by Alexis Barat on 20/04/2023.
//

import Foundation
import AVFoundation

public extension AVAudioSession.PortOverride {
    var readableDescription: String {
        switch self {
        case .none:
            return "none"
        case .speaker:
            return "speaker"
        @unknown default:
            return "unknown"
        }
    }
}

public extension AVAudioSession.Port {
    var readableDescription: String {
        switch self {
        case .lineIn:
            return "lineIn"
        case .builtInMic:
            return "builtInMic"
        case .headsetMic:
            return "headsetMic"
        case .lineOut:
            return "lineOut"
        case .headphones:
            return "headphones"
        case .bluetoothA2DP:
            return "bluetoothA2DP"
        case .builtInReceiver:
            return "builtInReceiver"
        case .builtInSpeaker:
            return "builtInSpeaker"
        case .HDMI:
            return "HDMI"
        case .airPlay:
            return "airPlay"
        case .bluetoothLE:
            return "bluetoothLE"
        case .bluetoothHFP:
            return "bluetoothHFP"
        case .usbAudio:
            return "usbAudio"
        case .carAudio:
            return "carAudio"
        case .virtual:
            return "virtual"
        case .PCI:
            return "PCI"
        case .fireWire:
            return "fireWire"
        case .displayPort:
            return "displayPort"
        case .AVB:
            return "AVB"
        case .thunderbolt:
            return "thunderbolt"
        default:
            return "unknown port"
        }
    }
}

public extension AudioSessionManager.AudioSessionConfiguration {
    var readableDescription: String {
        """
        * category: \(category.rawValue)
        * mode: \(mode.rawValue)
        """
    }
}

public extension AudioSessionManager.State {
    var readableDescription: String {
        switch self {
        case .uninitialized:
            return "uninitialized"
        case .error:
            return "error"
        case .configured:
            return "configured"
        case .recording(_, _, let paused, _, _, _):
            return "recording; paused: \(paused)"
        case .stoppingRecording(_, _, _, let cancelled):
            return "stoppingRecording, cancelled: \(cancelled)"
        case .playing(_, _, let paused):
            return "playing; paused: \(paused)"
        case .processing(_, _):
            return "processing"
        }
    }
}
