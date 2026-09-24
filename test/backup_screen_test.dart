import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paskluis_v1/features/settings/backup_screen.dart';
void main(){
 testWidgets('backup screen remains usable on a narrow phone with large text',(tester)async{
  await tester.binding.setSurfaceSize(const Size(360,780));
  addTearDown(()=>tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home:MediaQuery(data:const MediaQueryData(size:Size(360,780),textScaler:TextScaler.linear(2)),child:const BackupScreen())));
  await tester.pumpAndSettle();
  expect(tester.takeException(),isNull);
  expect(find.byType(ListView),findsOneWidget);
  await tester.drag(find.byType(ListView),const Offset(0,-400));await tester.pumpAndSettle();
  expect(tester.takeException(),isNull);
 });
}
