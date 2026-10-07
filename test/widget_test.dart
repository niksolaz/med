import 'package:flutter_test/flutter_test.dart';
import 'package:med/main.dart';
import 'package:med/services/storage_service.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    final storage = StorageService();
    await tester.pumpWidget(MedApp(storage: storage));
    expect(find.text('Nessun medicinale registrato'), findsOneWidget);
  });
}