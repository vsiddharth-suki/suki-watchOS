import AVFoundation
import Foundation
import WatchKit

enum DictationSoundPlayer {
    private static var player: AVAudioPlayer?

    /// iOS ambient pause cue (`Audio/exit_dictation.mp3`) plus watch haptics.
    static func playExitDictation() {
        let device = WKInterfaceDevice.current()
        device.play(.stop)
        device.play(.notification)

        guard let url = Bundle.main.url(forResource: "exit_dictation", withExtension: "mp3", subdirectory: "Audio")
            ?? Bundle.main.url(forResource: "exit_dictation", withExtension: "mp3")
        else {
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .duckOthers])
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.prepareToPlay()
            audioPlayer.play()
            player = audioPlayer
        } catch {
            // Non-fatal: recording pause should still succeed without the cue.
        }
    }
}
