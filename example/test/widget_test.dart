import 'package:flutter_test/flutter_test.dart';
import 'package:galva_flutter_example/main.dart';

void main() {
  testWidgets('the control panel says when no API key is set', (tester) async {
    await tester.pumpWidget(const GalvaExampleApp());
    await tester.pump();

    expect(find.textContaining('No GALVA_API_KEY'), findsOneWidget);
    expect(find.text('Identify'), findsOneWidget);
  });
}
