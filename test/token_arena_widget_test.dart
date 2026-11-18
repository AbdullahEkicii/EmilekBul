import 'package:emilekbul/screens/token_arena_common.dart';
import 'package:emilekbul/screens/token_arena_screen.dart';
import 'package:emilekbul/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'user_tokens': 150});
  });

  testWidgets('TokenArenaScreen tüm 5 oyunu, açıklamayı ve bahis seçiciyi gösterir',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const TokenArenaScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('mg.arena_hero_title'), findsOneWidget);
    expect(find.byType(ArenaStakeSelector), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);

    expect(find.text('mg.mines'), findsOneWidget);
    expect(find.text('mg.wheel'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('mg.higher_lower'), 200);
    expect(find.text('mg.higher_lower'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('mg.memory'), 200);
    expect(find.text('mg.memory'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('mg.reflex'), 200);
    expect(find.text('mg.reflex'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('ArenaResultBanner kazanç, kayıp ve kısmi iade durumlarını gösterir',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Column(
            children: const [
              ArenaResultBanner(won: true, stake: 50, payoutAmount: 90),
              ArenaResultBanner(won: false, stake: 50, payoutAmount: 25),
              ArenaResultBanner(won: false, stake: 50, payoutAmount: 0),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
    expect(find.byIcon(Icons.replay_circle_filled_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.text('mg.earn_tokens_cta'), findsNWidgets(2));
  });
}
