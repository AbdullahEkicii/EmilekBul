import 'package:emilekbul/features/duel/widgets/duel_lobby_widgets.dart';
import 'package:emilekbul/models/duel_room_model.dart';
import 'package:emilekbul/screens/main_shell.dart';
import 'package:emilekbul/services/themed_event_service.dart';
import 'package:emilekbul/theme/app_theme.dart';
import 'package:emilekbul/widgets/themed_event_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ThemedEventCard renders event metadata and invokes onTap',
      (tester) async {
    ThemedEvent? tappedEvent;
    final sampleEvent = ThemedEvent(
      id: 'science_week',
      titleKey: 'themed_event.science_title',
      subtitleKey: 'themed_event.science_sub',
      categoryName: 'Bilim',
      multiplier: 2,
      endsAt: DateTime.now().add(const Duration(days: 2)),
      accentColor: AppColors.accent,
      icon: Icons.science_rounded,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ThemedEventCard(
              event: sampleEvent,
              onTap: (e) => tappedEvent = e,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.science_rounded), findsOneWidget);
    expect(find.textContaining('science_title'), findsOneWidget);

    await tester.tap(find.byType(ThemedEventCard));
    await tester.pump();

    expect(tappedEvent, isNotNull);
    expect(tappedEvent!.categoryName, 'Bilim');
  });

  testWidgets('DuelRoomCodeCard triggers share and copy callbacks',
      (tester) async {
    bool shared = false;
    bool copied = false;
    final room = DuelRoom(
      roomCode: 'AB12CD',
      hostUid: 'u1',
      status: 'waiting',
      config: const DuelConfig(
        category: 'Bilim',
        difficulty: 'Orta',
        questionCount: 5,
        betTokens: 20,
      ),
      host: DuelPlayer(
        uid: 'u1',
        username: 'Host',
        avatarIndex: '0',
        equippedFrame: '0',
        equippedTitle: 'yok',
        tokens: 100,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: DuelRoomCodeCard(
            room: room,
            onShare: () => shared = true,
            onCopy: () => copied = true,
          ),
        ),
      ),
    );

    expect(find.text('AB12CD'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.share_rounded));
    await tester.tap(find.byIcon(Icons.copy_rounded));
    expect(shared, isTrue);
    expect(copied, isTrue);
  });

  testWidgets('AppTheme.dark applies AppColors surface and scaffold defaults',
      (tester) async {
    final theme = AppTheme.dark();
    expect(theme.scaffoldBackgroundColor, AppColors.backgroundTop);
    expect(theme.colorScheme.primary, AppColors.accent);
    expect(theme.colorScheme.surface, AppColors.surface);
  });

  testWidgets(
      'FloatingGlassTabBar renders 4 tabs with BackdropFilter blur and dispatches selection',
      (tester) async {
    int selected = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              extendBody: true,
              body: ListView.builder(
                itemCount: 20,
                itemBuilder: (_, i) => SizedBox(
                  height: 80,
                  child: ColoredBox(
                    color: i.isEven ? AppColors.accent : AppColors.amber,
                  ),
                ),
              ),
              bottomNavigationBar: FloatingGlassTabBar(
                selectedIndex: selected,
                onSelected: (i) => setState(() => selected = i),
                items: const [
                  FloatingTabItemData(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home_rounded,
                    label: 'Home',
                  ),
                  FloatingTabItemData(
                    icon: Icons.grid_view_outlined,
                    selectedIcon: Icons.grid_view_rounded,
                    label: 'Modes',
                  ),
                  FloatingTabItemData(
                    icon: Icons.emoji_events_outlined,
                    selectedIcon: Icons.emoji_events_rounded,
                    label: 'League',
                  ),
                  FloatingTabItemData(
                    icon: Icons.storefront_outlined,
                    selectedIcon: Icons.storefront_rounded,
                    label: 'Shop',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Modes'), findsOneWidget);
    expect(find.text('League'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);

    await tester.tap(find.text('League'));
    await tester.pumpAndSettle();
    expect(selected, 2);
    expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);

    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();
    expect(selected, 3);
    expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
  });
}
