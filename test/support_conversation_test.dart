import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:paskluis_v1/data/services/locale_service.dart';
import 'package:paskluis_v1/data/services/support_service.dart';
import 'package:paskluis_v1/features/support/support_thread_screen.dart';
import 'package:paskluis_v1/l10n/generated/app_localizations.dart';

final thread = SupportThread(id: 'thread', subject: 'Mijn vraag', status: 'open',
  createdAt: DateTime.utc(2026, 9, 22), updatedAt: DateTime.utc(2026, 9, 22));

SupportMessage message(String id, String kind, String time, {String? name}) =>
  SupportMessage(id: id, senderId: kind == 'guest' ? '' : kind,
    senderKind: kind, senderName: name, message: id, createdAt: DateTime.parse(time));
final question = message('Mijn bericht', 'guest', '2026-09-22T14:30:00Z');
final reply = message('Het antwoord', 'staff', '2026-09-22T16:33:00+02:00', name: 'Ronald');
SupportConversation snapshot(List<SupportMessage> messages) =>
  SupportConversation(thread: thread, messages: messages);

Future<void> mount(WidgetTester tester, Future<SupportConversation> Function() load,
  {Future<List<Map<String, dynamic>>> Function()? attachments}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(locale: const Locale('nl'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: SupportThreadScreen(thread: thread, loadConversation: load,
      loadAttachments: attachments ?? () async => [])));
  await tester.pump();
}

Future<void> close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocaleService.init();
    await LocaleService.setLanguage('nl');
  });

  test('messages sort by instant, then ID for ties, without changing the input', () {
    final rows = [reply, question];
    expect(snapshot(rows).messages.map((m) => m.id), ['Mijn bericht', 'Het antwoord']);
    expect(rows.first, reply);
    final a = message('a', 'user', '2026-09-22T14:30:00.000001Z');
    final b = message('b', 'automatic', '2026-09-22T14:30:00.000002Z');
    expect(snapshot([b, a]).messages.first.id, 'a');
  });

  testWidgets('customer is right, named staff left, newest answer below question', (tester) async {
    await mount(tester, () async => snapshot([reply, question]));
    await tester.pumpAndSettle();
    expect(find.text('Jij'), findsOneWidget);
    expect(find.text('Ronald · PasKluis'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Mijn bericht')).dy,
      lessThan(tester.getTopLeft(find.text('Het antwoord')).dy));
    for (final entry in {question.id: Alignment.centerRight, reply.id: Alignment.centerLeft}.entries) {
      final align = find.descendant(of: find.byKey(ValueKey(entry.key)), matching: find.byType(Align)).first;
      expect(tester.widget<Align>(align).alignment, entry.value);
    }
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('a delayed or failing attachment request cannot hide the reply', (tester) async {
    final pending = Completer<List<Map<String, dynamic>>>();
    await mount(tester, () async => snapshot([question, reply]), attachments: () => pending.future);
    await tester.pumpAndSettle();
    expect(find.text('Het antwoord'), findsOneWidget);
    pending.completeError(StateError('Attachment unavailable'));
    await tester.pump();
    expect(find.text('Het antwoord'), findsOneWidget);
    await close(tester);
  });

  testWidgets('an older slow refresh cannot overwrite a newer answer', (tester) async {
    final old = Completer<SupportConversation>();
    var calls = 0;
    await mount(tester, () => ++calls == 1 ? old.future : Future.value(snapshot([question, reply])));
    await tester.tap(find.byTooltip('Vernieuwen'));
    await tester.pumpAndSettle();
    expect(find.text('Het antwoord'), findsOneWidget);
    old.complete(snapshot([question]));
    await tester.pumpAndSettle();
    expect(find.text('Het antwoord'), findsOneWidget);
    await close(tester);
  });

  testWidgets('foreground push and resume refresh the correct conversation', (tester) async {
    var calls = 0;
    await mount(tester, () async { calls++; return snapshot(calls == 1 ? [question] : [question, reply]); });
    await tester.pumpAndSettle();
    SupportService.notifyConversationChanged('another-thread');
    await tester.pump();
    expect(calls, 1);
    SupportService.notifyConversationChanged(thread.id);
    await tester.pumpAndSettle();
    expect(find.text('Het antwoord'), findsOneWidget);
    expect(calls, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(calls, 3);
    await close(tester);
  });

  testWidgets('failed refresh shows a retry and recovers without hiding existing messages', (tester) async {
    var calls = 0;
    await mount(tester, () async {
      if (++calls == 2) throw StateError('Offline');
      return snapshot(calls == 1 ? [question] : [question, reply]);
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Vernieuwen'));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(find.text('Mijn bericht'), findsOneWidget);
    await tester.tap(find.byTooltip('Vernieuwen'));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialBanner), findsNothing);
    expect(find.text('Het antwoord'), findsOneWidget);
    await close(tester);
  });

  testWidgets('revoked access clears previously displayed conversation data', (tester) async {
    var calls = 0;
    await mount(tester, () async {
      if (++calls > 1) throw const PostgrestException(message: 'CONVERSATION_UNAVAILABLE', code: '42501');
      return snapshot([question, reply]);
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Vernieuwen'));
    await tester.pumpAndSettle();
    expect(find.text('Mijn bericht'), findsNothing);
    expect(find.text('Het antwoord'), findsNothing);
    expect(find.byType(MaterialBanner), findsOneWidget);
    await close(tester);
  });
}
