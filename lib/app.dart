import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/home_page.dart';

class RuamportApp extends StatelessWidget {
  const RuamportApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Ruamport',
    debugShowCheckedModeBanner: false,
    theme: createAppTheme(),
    home: const HomePage(),
  );
}
