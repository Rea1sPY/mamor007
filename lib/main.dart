import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/store.dart';
import 'core/theme.dart';
import 'features/splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: C.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  await Store.i.init();
  // Third-party licenses shown on the About > Licenses page.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
        ['Vazirmatn font'], await rootBundle.loadString('assets/licenses/OFL-Vazirmatn.txt'));
    yield LicenseEntryWithLineBreaks(
        ['Kenney Interface Sounds'], await rootBundle.loadString('assets/licenses/CC0-Kenney.txt'));
  });
  runApp(const CaseApp());
}

class CaseApp extends StatelessWidget {
  const CaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) => MaterialApp(
        title: 'CASE 007',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('fa'),
        supportedLocales: const [Locale('fa')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(Store.i.largeFont ? 1.18 : 1.0),
          ),
          child: child!,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
