import 'package:shared_preferences/shared_preferences.dart';

// When match starts or player joins the match:
Future<void> saveMatchId(String matchId) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString('currentMatchId', matchId);
}
