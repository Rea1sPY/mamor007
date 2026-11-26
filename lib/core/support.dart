import 'package:url_launcher/url_launcher.dart';

const supportHandle = 'MaTeoHastam';
const creditName = 'ReaLsPY';
const appVersion = '1.5.0';

Future<bool> openSupport() async {
  final app = Uri.parse('tg://resolve?domain=$supportHandle');
  final web = Uri.parse('https://t.me/$supportHandle');
  try {
    if (await launchUrl(app, mode: LaunchMode.externalApplication)) return true;
  } catch (_) {}
  try {
    return await launchUrl(web, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
