import 'package:flutter/material.dart';

import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

class SpendDiaryApp extends StatelessWidget {
  const SpendDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpendDiary',
      theme: AppTheme.build(),
      initialRoute: AppRoutes.onboarding,
      routes: AppRoutes.routes,
    );
  }
}
