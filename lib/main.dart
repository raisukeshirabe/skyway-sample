import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:skyway_sample/video_call_page.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skyway Sample'),
      ),
      body: Center(
        child: ElevatedButton(
          child: const Text('Connect'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => VideoCallPage(),
            ),
          ),
        ),
      ),
    );
  }
}
