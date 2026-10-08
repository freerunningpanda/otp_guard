import 'dart:async';

import 'package:device_security/device_security.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({required this.title, super.key});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  bool _isScreenProtectionEnabled = false;

  // A demo of the device key API: runs a scenario at start and shows what
  // each call returned. The "Run key checks" button runs it again.
  String _keyLog = 'running...';

  @override
  void initState() {
    super.initState();
    unawaited(_runKeyChecks());
  }

  Future<void> _runKeyChecks() async {
    final security = DeviceSecurity();
    const alias = 'temp_check_key';
    final log = StringBuffer();

    Future<void> step(String name, Future<Object?> Function() body) async {
      String line;
      try {
        line = 'OK   $name -> ${await body()}';
      } on PlatformException catch (e) {
        line = 'ERR  $name -> ${e.code}: ${e.message}';
      }
      log.writeln(line);
      debugPrint('KEYCHECK $line');
    }

    await step('isDeviceSecure', security.isDeviceSecure);
    await step('deleteKey (clean start)', () => security.deleteKey(alias));
    await step('hasKey, expect false', () => security.hasKey(alias));
    await step('generateKey #1', () async {
      final key = await security.generateKey(alias);
      final head = key
          .take(4)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      return '${key.length} bytes, starts $head';
    });
    await step('hasKey, expect true', () => security.hasKey(alias));
    await step(
      'generateKey #2, expect KEY_EXISTS',
      () => security.generateKey(alias),
    );
    await step('deleteKey', () => security.deleteKey(alias));
    await step('hasKey, expect false', () => security.hasKey(alias));
    await step('deleteKey again, expect OK', () => security.deleteKey(alias));

    if (mounted) setState(() => _keyLog = log.toString());
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isScreenProtectionEnabled = !_isScreenProtectionEnabled;
                });
                DeviceSecurity().setScreenProtection(
                  enabled: _isScreenProtectionEnabled,
                );
              },
              child: _isScreenProtectionEnabled
                  ? const Text('Disable screen protection')
                  : const Text('Enable screen protection'),
            ),
            // Runs the key scenario again and shows its result.
            ElevatedButton(
              onPressed: _runKeyChecks,
              child: const Text('Run key checks'),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _keyLog,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
