import 'package:flutter_test/flutter_test.dart';

import 'package:opd_connect/main.dart';

// OpdApp (the real root in lib/app.dart) listens to FirebaseAuth as soon as it
// is built, so it cannot be pumped without a Firebase mock. SetupErrorApp is
// the root widget main.dart runs when Firebase is missing, and it builds
// offline, so this smoke test uses it.
void main() {
  testWidgets('Root widget in main.dart builds and shows its message', (WidgetTester tester) async {
    await tester.pumpWidget(const SetupErrorApp(message: 'test message'));

    expect(find.text('Firebase setup required'), findsOneWidget);
    expect(find.text('test message'), findsOneWidget);
  });
}
