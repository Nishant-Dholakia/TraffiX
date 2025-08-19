import 'package:audioplayers/audioplayers.dart';

class SoundManager {
  static final _player = AudioPlayer();

  static Future<void> playSend() async {
    await _player.play(AssetSource('sounds/send.mp3'));
  }

  static Future<void> playReceive() async {
    await _player.play(AssetSource('sounds/receive.mp3'));
  }
}
