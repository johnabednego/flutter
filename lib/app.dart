import 'package:flutter/material.dart';
import 'package:flutter_application_1/home.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Video Application',
      debugShowCheckedModeBanner: false,
      home: Home(),
    );
  }
}
