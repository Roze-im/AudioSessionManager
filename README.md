# AudioSessionManager

## Playback

`public func startPlayingItem(_ item: AudioItem) -> Error?`

`public func pausePlayingItem(_ item: AudioItem) -> Error?`

`public func stopPlayingItem(_ item: AudioItem, deactivateSession: Bool)`

`public func setPlayerRate(rate: Float, items: [AudioItem])`

`public func moveItemCursor(item: AudioItem, percent: Float)`


## Record

`public func startRecordingAudio(durationLimit: TimeInterval?) -> Error?`

`public func stopRecordingAudio(cancelled: Bool)`

`public func getRecorderAveragePower() -> Float?`


## Misc

`public func startProcessingItem(_ item: AudioItem) -> Error?`


## Delegate methods

```
    func audioSessionManagerDidUpdateState(_ manager: AudioSessionManager)
    func audioSessionManager(
        _ manager: AudioSessionManager,
        didStartPlaying item: AudioSessionManager.AudioItem
    )
    func audioSessionManager(
        _ manager: AudioSessionManager,
        didStopPlaying item: AudioSessionManager.AudioItem
    )
    func audioSessionManager(
        _ manager: AudioSessionManager,
        didPausePlaying item: AudioSessionManager.AudioItem
    )
    func audioSessionManager(
        _ manager: AudioSessionManager,
        didFinishPlaying item: AudioSessionManager.AudioItem
    )

    func audioSessionManagerDidStartRecording(
        _ manager: AudioSessionManager
    )
    func audioSessionManagerDidStopRecording(
        _ manager: AudioSessionManager,
        cancelled: Bool,
        output: (url: URL, metadata: AudioSessionManager.AudioMetadata)?
    )

    func audioSessionManager(
        _ manager: AudioSessionManager,
        didStartProcessing item: AudioSessionManager.AudioItem
    )
    func audioSessionManager(
        _ manager: AudioSessionManager,
        didFinishProcessing item: AudioSessionManager.AudioItem,
        hasRemainingItems: Bool
    )
```
