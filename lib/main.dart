import 'package:flutter/material.dart';
import 'package:fpaint/home_screen.dart';
import 'package:provider/provider.dart';
import 'paint_model.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PaintModel(),
      child: MaterialApp(
        title: 'Flutter Paint App',
        home: HomeScreen(),
      ),
    );
  }
}
