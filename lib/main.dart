import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme.dart';
import 'screens/lock_screen.dart';
import 'services/app_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final services = AppServices();
  await services.init();
  runApp(MasterSafetyApp(services: services));
}

class MasterSafetyApp extends StatelessWidget {
  final AppServices services;
  const MasterSafetyApp({super.key, required this.services});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MasterSafety',
        debugShowCheckedModeBanner: false,
        theme: MS.theme(),
        home: LockScreen(services: services),
      );
}
