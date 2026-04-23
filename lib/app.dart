import 'package:flutter/material.dart';

import 'presentation/app_root.dart';

class SharedListsApp extends StatelessWidget {
  const SharedListsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shared Lists Offline',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F6F5B)),
        useMaterial3: true,
      ),
      home: const AppRoot(),
    );
  }
}
