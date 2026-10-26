import 'package:shared_preferences/shared_preferences.dart';

import 'pane_controller.dart';

const _leftKey = 'last_opened_path_left';
const _rightKey = 'last_opened_path_right';

/// 패널별 마지막으로 연 디렉토리. 원격 경로(FTP/SFTP/WebDAV·매핑된 네트워크
/// 드라이브)는 저장하지 않는다 — 시작할 때 다시 시도하지 않고 기본 경로를
/// 열기로 했으므로, "마지막으로 연 디렉토리"로도 치지 않는다.
class LastOpenedPathStore {
  const LastOpenedPathStore._();

  static String _keyFor(PaneSide side) => side == PaneSide.left ? _leftKey : _rightKey;

  static Future<String?> read(PaneSide side) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFor(side));
  }

  static Future<void> save(PaneSide side, String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFor(side), path);
  }
}
