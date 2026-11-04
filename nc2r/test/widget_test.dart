import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nc2r/main.dart';
import 'package:nc2r/providers/api_provider.dart';
import 'package:nc2r/screens/login_screen.dart';
import 'package:nc2r/services/token_storage.dart';

class _FakeTokenStorage extends TokenStorage {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

void main() {
  testWidgets('App shows login screen when logged out', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
        ],
        child: const NC2RApp(),
      ),
    );
    await tester.pump();
    await tester.pump();
    // Let the splash->login AnimatedSwitcher crossfade (450ms) finish so
    // the outgoing splash screen is fully removed from the tree instead
    // of briefly overlapping with the login screen.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('NC2R'), findsOneWidget);
  });
}
