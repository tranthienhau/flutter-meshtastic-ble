import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/scan_screen.dart';

void main() {
  runApp(const ProviderScope(child: MeshtasticApp()));
}

class MeshtasticApp extends StatelessWidget {
  const MeshtasticApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meshtastic BLE Gateway',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF67C28D),
        brightness: Brightness.dark,
      ),
      home: const ScanScreen(),
    );
  }
}
