import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:galva_flutter/galva_flutter.dart';

/// Your App ID, passed at build time so it stays out of source control:
/// `flutter run --dart-define=GALVA_API_KEY=pk_… --dart-define=GALVA_ENV=development`
const _apiKey = String.fromEnvironment('GALVA_API_KEY');
const _env = String.fromEnvironment('GALVA_ENV', defaultValue: 'production');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_apiKey.isNotEmpty) {
    await Galva.instance.configure(
      GalvaConfiguration(
        apiKey: _apiKey,
        environment: _env == 'development' ? GalvaEnvironment.development : GalvaEnvironment.production,
        logLevel: GalvaLogLevel.debug,
        // Manual, to show the stream and showMessage at work; most apps keep the default.
        inAppMessages: GalvaInAppMessagesPresentation.manual,
      ),
    );
  }
  runApp(const GalvaExampleApp());
}

class GalvaExampleApp extends StatelessWidget {
  const GalvaExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Galva example',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF135FF8)),
      home: const ControlPanel(),
    );
  }
}

class ControlPanel extends StatefulWidget {
  const ControlPanel({super.key});

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  final _userId = TextEditingController(text: 'flutter-user-1');
  final _email = TextEditingController();
  final _link = TextEditingController(text: 'gv-your-scheme://openCommunication?communicationId=test');
  StreamSubscription<GalvaInAppMessage>? _messages;

  String _status = '';
  final _log = <String>[];

  @override
  void initState() {
    super.initState();
    _messages = Galva.instance.inAppMessageStream.listen((message) {
      _write('Message ${message.id} (${message.workflowType ?? 'no flow'}) received');
      _run('showMessage', () => Galva.instance.showMessage(message));
    });
    _refresh();
  }

  @override
  void dispose() {
    _messages?.cancel();
    _userId.dispose();
    _email.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_apiKey.isEmpty) {
      setState(() => _status = 'No GALVA_API_KEY: pass --dart-define=GALVA_API_KEY=pk_… to configure Galva.');
      return;
    }
    try {
      final configured = await Galva.instance.isConfigured();
      final userId = await Galva.instance.getIdentifiedUserId();
      final optedOut = await Galva.instance.isOptedOut();
      setState(() => _status = 'configured: $configured · user: ${userId ?? 'anonymous'} · opted out: $optedOut');
    } on GalvaError catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  void _write(String line) => setState(() => _log.insert(0, line));

  Future<void> _run(String name, Future<Object?> Function() call) async {
    try {
      final result = await call();
      _write('$name → ${result ?? 'ok'}');
    } on GalvaError catch (e) {
      _write('$name failed: $e');
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Galva ${Galva.sdkVersion}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_status, key: const Key('status')),
          const SizedBox(height: 16),
          TextField(controller: _userId, decoration: const InputDecoration(labelText: 'User ID')),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email (optional)')),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: () => _run('identify', () {
                  final email = _email.text.trim();
                  return Galva.instance.identify(_userId.text.trim(), email: email.isEmpty ? null : email);
                }),
                child: const Text('Identify'),
              ),
              OutlinedButton(onPressed: () => _run('logout', Galva.instance.logout), child: const Text('Log out')),
              OutlinedButton(
                onPressed: () => _run('setAttributes', () {
                  return Galva.instance.setAttributes(
                    const GalvaUserAttributes(firstName: 'Ana', custom: {'plan_tier': 'pro', 'habit_count': 13}),
                  );
                }),
                child: const Text('Set attributes'),
              ),
              OutlinedButton(
                onPressed: () => _run('track', () {
                  return Galva.instance.track('DemoButtonTapped', attributes: {'screen': 'control_panel'});
                }),
                child: const Text('Track event'),
              ),
            ],
          ),
          const Divider(height: 32),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _run('checkForMessages', Galva.instance.checkForMessages),
                child: const Text('Check for messages'),
              ),
              OutlinedButton(
                onPressed: () => _run('setOptOut', () async {
                  final optedOut = !await Galva.instance.isOptedOut();
                  await Galva.instance.setOptOut(optedOut);
                  return optedOut ? 'opted out' : 'opted in';
                }),
                child: const Text('Toggle opt-out'),
              ),
              OutlinedButton(
                onPressed: () => _run('reconcileTransactions', Galva.instance.reconcileTransactions),
                child: const Text('Reconcile purchases'),
              ),
            ],
          ),
          TextField(controller: _link, decoration: const InputDecoration(labelText: 'Galva link')),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () => _run('handleOpenUrl', () => Galva.instance.handleOpenUrl(_link.text.trim())),
              child: const Text('Open link'),
            ),
          ),
          const Divider(height: 32),
          for (final line in _log) Text(line, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
