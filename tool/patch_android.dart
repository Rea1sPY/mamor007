import 'dart:io';

void main() {
  final f = File('android/app/src/main/AndroidManifest.xml');
  if (!f.existsSync()) {
    stderr.writeln('android folder not found. Run flutter create first.');
    exit(1);
  }
  var s = f.readAsStringSync();
  if (s.contains('ACCESS_WIFI_STATE')) {
    stdout.writeln('Manifest already patched.');
    return;
  }
  const perms = '''
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
    <uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-feature android:name="android.hardware.camera" android:required="false"/>
''';
  const intents = '''
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="tg"/></intent>
''';
  s = s.replaceFirst('<application', '$perms    <application');
  s = s.replaceFirstMapped(RegExp(r'android:label="[^"]*"'), (m) => 'android:label="CASE 007" android:usesCleartextTraffic="true"');
  if (s.contains('<queries>')) {
    s = s.replaceFirst('<queries>', '<queries>$intents');
  } else {
    s = s.replaceFirst('</manifest>', '    <queries>$intents    </queries>\n</manifest>');
  }
  f.writeAsStringSync(s);
  stdout.writeln('Manifest patched.');
}
