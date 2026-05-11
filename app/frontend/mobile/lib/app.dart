import 'package:flutter/material.dart';

import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

class SpendDiaryApp extends StatelessWidget {
  const SpendDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SpendDiary',
      theme: AppTheme.build(),
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
