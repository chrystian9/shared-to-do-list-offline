import 'package:flutter/material.dart';

import '../application/app_service.dart';
import '../app.dart';
import '../data/repositories/shared_prefs_settings_repository.dart';
import '../data/repositories/sqlite_operation_repository.dart';
import '../data/repositories/sqlite_snapshot_repository.dart';
import '../data/storage/local_database.dart';
import '../sync/transports.dart';
import 'home_screen.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  Future<AppService>? _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _buildService();
  }

  Future<AppService> _buildService() async {
    final database = await LocalDatabase.open();
    final service = AppService(
      operationRepository: SqliteOperationRepository(database.database),
      snapshotRepository: SqliteSnapshotRepository(database.database),
      settingsRepository: SharedPrefsSettingsRepository(),
      syncTransport: const ManualJsonSyncTransport(),
    );
    await service.initialize();
    return service;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppService>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        final service = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            title: 'To-Do List',
            theme: buildAppTheme(Brightness.light),
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError || service == null) {
          return MaterialApp(
            title: 'To-Do List',
            theme: buildAppTheme(Brightness.light),
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Failed to initialize app: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }

        return AnimatedBuilder(
          animation: service,
          builder: (context, _) {
            final theme = service.themeMode == AppThemeMode.terminal
                ? buildTerminalTheme()
                : buildAppTheme(Brightness.light);
            return MaterialApp(
              title: 'To-Do List',
              theme: theme,
              home: HomeScreen(service: service),
            );
          },
        );
      },
    );
  }
}
