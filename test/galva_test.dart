import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:galva_flutter/galva_flutter.dart';

const _channel = MethodChannel('flutter.galva.io/galva');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;
  late Object? Function(MethodCall call) respond;

  setUp(() {
    calls = [];
    respond = (_) => {'success': true};
    messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      final response = respond(call);
      return response == null ? null : json.encode(response);
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  Map<String, dynamic> argsOf(MethodCall call) => json.decode(call.arguments as String) as Map<String, dynamic>;

  group('requests follow cross_platform.yaml', () {
    test('configure sends the configuration with the wrapper', () async {
      await Galva.instance.configure(
        const GalvaConfiguration(
          apiKey: 'pk_test',
          environment: GalvaEnvironment.custom(apiUrl: 'https://api.example.com/', webviewUrl: 'https://cdn.example.com/'),
          logLevel: GalvaLogLevel.debug,
          inAppMessages: GalvaInAppMessagesPresentation.manual,
          autoTrackSessions: false,
        ),
      );

      expect(calls.single.method, 'configure');
      expect(argsOf(calls.single)['configuration'], {
        'api_key': 'pk_test',
        'environment': {'type': 'custom', 'api_url': 'https://api.example.com/', 'webview_url': 'https://cdn.example.com/'},
        'log_level': 'debug',
        'in_app_messages': 'manual',
        'auto_track_sessions': false,
        'ios_apple_search_ads': true,
        'wrapper': {'name': 'flutter', 'version': Galva.sdkVersion},
      });
    });

    test('identify leaves out arguments that are null', () async {
      await Galva.instance.identify('user_42', email: 'ana@example.com');

      expect(calls.single.method, 'identify');
      expect(argsOf(calls.single), {'user_id': 'user_42', 'email': 'ana@example.com'});
    });

    test('setAttributes sends only the fields that are set', () async {
      await Galva.instance.setAttributes(
        const GalvaUserAttributes(firstName: 'Ana', custom: {'plan_tier': 'pro', 'tags': ['a', 'b'], 'none': null}),
      );

      expect(argsOf(calls.single)['attributes'], {
        'first_name': 'Ana',
        'custom': {'plan_tier': 'pro', 'tags': ['a', 'b'], 'none': null},
      });
    });

    test('track sends attributes only when there are some', () async {
      await Galva.instance.track('Opened');
      await Galva.instance.track('Purchase', attributes: {'price': 9.99});

      expect(argsOf(calls[0]), {'event_name': 'Opened'});
      expect(argsOf(calls[1]), {'event_name': 'Purchase', 'attributes': {'price': 9.99}});
    });

    test('showMessage sends the message as delivered', () async {
      await Galva.instance.showMessage(
        GalvaInAppMessage(
          id: 'm1',
          workflowType: GalvaWorkflowType.winback,
          createdAt: DateTime.utc(2026, 11, 3, 10, 0, 0, 123),
        ),
      );

      expect(argsOf(calls.single)['message'], {
        'id': 'm1',
        'workflow_type': 'winback',
        'created_at': '2026-11-03T10:00:00.000Z',
      });
    });
  });

  group('responses', () {
    test('success values are returned', () async {
      respond = (call) => switch (call.method) {
            'is_opted_out' => {'success': true},
            'get_identified_user_id' => {'success': null},
            'handle_open_url' => {'success': false},
            _ => {'success': true},
          };

      expect(await Galva.instance.isOptedOut(), isTrue);
      expect(await Galva.instance.getIdentifiedUserId(), isNull);
      expect(await Galva.instance.handleOpenUrl('https://example.com'), isFalse);
    });

    test('an error response throws GalvaError', () async {
      respond = (_) => {
            'error': {'code': GalvaErrorCode.messageNotFound, 'message': 'gone', 'detail': 'm1'},
          };

      await expectLater(
        Galva.instance.showMessage(const GalvaInAppMessage(id: 'm1')),
        throwsA(isA<GalvaError>()
            .having((e) => e.code, 'code', GalvaErrorCode.messageNotFound)
            .having((e) => e.detail, 'detail', 'm1')),
      );
    });

    test('a null response throws emptyResult', () async {
      respond = (_) => null;

      await expectLater(
        Galva.instance.logout(),
        throwsA(isA<GalvaError>().having((e) => e.code, 'code', GalvaErrorCode.emptyResult)),
      );
    });

    test('a missing native implementation throws methodNotImplemented', () async {
      messenger.setMockMethodCallHandler(_channel, null);

      await expectLater(
        Galva.instance.logout(),
        throwsA(isA<GalvaError>().having((e) => e.code, 'code', GalvaErrorCode.methodNotImplemented)),
      );
    });
  });

  group('events', () {
    test('in_app_message_received reaches inAppMessageStream', () async {
      await Galva.instance.configure(const GalvaConfiguration(apiKey: 'pk_test'));
      final received = Galva.instance.inAppMessageStream.first;

      await messenger.handlePlatformMessage(
        'flutter.galva.io/galva',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(
            'in_app_message_received',
            json.encode({
              'message': {'id': 'm2', 'workflow_type': 'trial-rescue', 'created_at': '2026-11-03T10:00:00Z'},
            }),
          ),
        ),
        (_) {},
      );

      final message = await received.timeout(const Duration(seconds: 1));
      expect(message.id, 'm2');
      expect(message.workflowType, GalvaWorkflowType.trialRescue);
      expect(message.createdAt, DateTime.utc(2026, 11, 3, 10));
    });

    test('a workflow type the plugin does not know is kept', () async {
      await Galva.instance.configure(const GalvaConfiguration(apiKey: 'pk_test'));
      final received = Galva.instance.inAppMessageStream.first;

      await messenger.handlePlatformMessage(
        'flutter.galva.io/galva',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('in_app_message_received', json.encode({'message': {'id': 'm3', 'workflow_type': 'future-flow'}})),
        ),
        (_) {},
      );

      final message = await received.timeout(const Duration(seconds: 1));
      expect(message.workflowType, const GalvaWorkflowType('future-flow'));
      expect(message.createdAt, isNull);
    });
  });

  group('platform-only calls', () {
    test('Android push calls do nothing on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await Galva.instance.setPushToken('fcm-token');
      await Galva.instance.handlePush({'communicationId': 'c1'});
      expect(await Galva.instance.isGalvaNotification({'communicationId': 'c1'}), isFalse);
      expect(calls, isEmpty);

      await Galva.instance.setApnsToken('abcd');
      expect(calls.single.method, 'set_apns_token');
    });

    test('setApnsToken does nothing on Android, push calls go through', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await Galva.instance.setApnsToken('abcd');
      expect(calls, isEmpty);

      await Galva.instance.setPushToken('hms-token', provider: GalvaPushProvider.hms);
      expect(calls.single.method, 'set_push_token');
      expect(argsOf(calls.single), {'token': 'hms-token', 'provider': 'hms'});
    });
  });
}
