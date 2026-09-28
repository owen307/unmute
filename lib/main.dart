import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'state/show_controller.dart';
import 'storage/show_repository.dart';
import 'theme.dart';
import 'transport/udp_osc_transport.dart';
import 'ui/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UnmuteApp());
}

class UnmuteApp extends StatefulWidget {
  const UnmuteApp({super.key, this.controller});

  /// Injected in tests. The phone build loads the on-device show itself.
  final ShowController? controller;

  @override
  State<UnmuteApp> createState() => _UnmuteAppState();
}

class _UnmuteAppState extends State<UnmuteApp> {
  ShowController? _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    final injected = widget.controller;
    if (injected != null) {
      _controller = injected;
    } else {
      _ownsController = true;
      _boot();
    }
  }

  Future<void> _boot() async {
    final prefs = await SharedPreferences.getInstance();
    final controller = ShowController(
      repository: PrefsShowRepository(prefs),
      transport: createOscTransport(),
    );
    await controller.load();
    if (!mounted) {
      controller.dispose();
      return;
    }
    setState(() => _controller = controller);
  }

  @override
  void dispose() {
    if (_ownsController) _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return MaterialApp(
      title: 'Unmute',
      theme: buildUnmuteTheme(),
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      home: controller == null
          ? const _BootScreen()
          : HomeShell(controller: controller),
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'UNMUTE',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
      ),
    );
  }
}
