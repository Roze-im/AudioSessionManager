//
//  AudioPlayer.swift
//
//
//  Created by Thibaud David on 08/03/2024.
//

import Foundation
import AVFoundation

protocol AudioPlayer {
    func startPlaying() -> Bool
    func pause()
    func stop()
    func moveToStart()
}

extension AVAudioPlayer: AudioPlayer {
    func startPlaying() -> Bool {
        return play()
    }
    func moveToStart() {
        currentTime = 0
    }
}
extension AVPlayer: AudioPlayer {
    func startPlaying() -> Bool {
        play()
        return true
    }
    func stop() {
        pause()
    }
    func moveToStart() {
        seek(to: .zero)
    }
}
