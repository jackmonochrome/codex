import AVFoundation
import Foundation

final class OverlayAudioPlayer: NSObject, AVAudioPlayerDelegate {
    private var activePlayers: [ObjectIdentifier: AVAudioPlayer] = [:]

    func play(url: URL) throws {
        let player = try AVAudioPlayer(contentsOf: url)
        player.delegate = self
        player.prepareToPlay()
        player.play()
        activePlayers[ObjectIdentifier(player)] = player
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        activePlayers.removeValue(forKey: ObjectIdentifier(player))
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        activePlayers.removeValue(forKey: ObjectIdentifier(player))
    }
}
