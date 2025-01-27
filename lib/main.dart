import 'package:flutter/material.dart';
import 'package:fpaint/main_screen.dart';
import 'package:provider/provider.dart';
import 'models/app_model.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppModel(),
      child: const MaterialApp(
        title: 'Flutter Paint App',
        home: MainScreen(),
      ),
    );
  }
}
