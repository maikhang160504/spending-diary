import 'package:flutter/material.dart';

import 'routes/app_routes.dart';
import 'services/connection_manager.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/lost_connection_overlay.dart';

class SpendDiaryApp extends StatelessWidget {
  const SpendDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'SpendDiary',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeController.instance.mode,
          routerConfig: appRouter,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return Stack(
              children: [
                ?child,
                ValueListenableBuilder<bool>(
                  valueListenable: ConnectionManager.instance.connectionLost,
                  builder: (context, lost, _) {
                    if (lost) {
                      return const Positioned.fill(
                        child: LostConnectionOverlay(),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
