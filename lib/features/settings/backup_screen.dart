import 'package:flutter/material.dart';
import '../../data/services/account_service.dart';
import '../../data/services/backup_service.dart';
import '../../data/services/locale_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/supabase_service.dart';
import '../account/account_screen.dart';

class BackupScreen extends StatefulWidget {
 const BackupScreen({super.key});
 @override State<BackupScreen> createState()=>_BackupScreenState();
}
class _BackupScreenState extends State<BackupScreen> {
 Map? _overview;
 String t(String nl,String en)=>LocaleService.languageCode=='nl'?nl:en;
 @override void initState(){super.initState();BackupService.refresh();_loadOverview();}
 Future<void> _loadOverview() async {
  try{if(await AccountService.isCurrentUserAdmin()){
   final r=await SupabaseService.client!.rpc('backup_admin_overview');if(mounted)setState(()=>_overview=r as Map);
  }}catch(_){/* Optional admin summary. */}
 }
 Future<bool> _confirm(String title,String body) async => await showDialog<bool>(context:context,builder:(c)=>AlertDialog(
  title:Text(title),content:Text(body),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:Text(t('Annuleren','Cancel'))),FilledButton(onPressed:()=>Navigator.pop(c,true),child:Text(t('Doorgaan','Continue')))],
 ))??false;
 String message(String code)=>switch(code){
  'RESTORE_FIRST'=>t('Er staat al een back-up klaar. Herstel die eerst voordat je automatische back-up op dit toestel inschakelt.','A backup already exists. Restore it before enabling automatic backup on this device.'),
  'BACKUP_QUOTA'=>t('De back-up past niet binnen 10 MB voor drie versies samen. Verklein of verwijder eigen afbeeldingen. Je vorige back-up blijft bewaard.','The backup exceeds 10 MB across three versions. Reduce or remove custom images. Your previous backup is safe.'),
  'IMAGE_MISSING'=>t('Een eigen afbeelding ontbreekt op dit toestel. Voeg die opnieuw toe; de vorige back-up blijft bewaard.','A custom image is missing. Add it again; the previous backup is safe.'),
  'SESSION_REPLACED'||'ACCOUNT_CHANGED'=>t('Je account of actieve toestel is gewijzigd. Log opnieuw in.','Your account or active device changed. Please sign in again.'),
  'BACKUP_BUSY'=>t('Er wordt al een back-up verwerkt. Probeer het over enkele minuten opnieuw.','A backup is already being processed. Try again in a few minutes.'),
  'NOT_AVAILABLE'=>t('Back-up is voorlopig beschikbaar voor de testgroep.','Backup is currently available to the test group.'),
  _=>t('De actie is niet gelukt. Controleer je internetverbinding en probeer opnieuw.','The action failed. Check your connection and try again.'),
 };
 Future<void> _enable(bool value) async {
  if(value && !await _confirm(t('Automatische back-up inschakelen?','Enable automatic backup?'),t('Je eigen kaarten, pincodes en afbeeldingen worden versleuteld bij je account opgeslagen. Niet-gekoppelde kaarten op dit toestel worden aan dit back-upaccount gekoppeld. Ontvangen gedeelde kaarten worden niet meegenomen. Maximaal 10 MB en drie versies.','Your own cards, PINs and images will be encrypted and saved to your account. Unassigned cards on this device will be linked to this backup account. Received shared cards are excluded. Maximum 10 MB and three versions.')))return;
  try{await BackupService.setEnabled(value);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message(e.toString().split(': ').last))));}
 }
 Future<void> _restore(Map version) async {
  if(!await _confirm(t('Back-up herstellen?','Restore backup?'),t('Deze versie bevat ${version['cardCount']} kaarten. Ontbrekende kaarten worden toegevoegd. Je huidige kaarten worden niet verwijderd. Een opgeslagen cadeaukaartsaldo kan verouderd zijn.','This version contains ${version['cardCount']} cards. Missing cards will be added. Current cards will not be deleted. Saved gift card balances may be outdated.')))return;
  final prepared=await BackupService.prepareRestore(version['id']);if(prepared==null||!mounted)return;
  final localIds=StorageService.cardsBox.values.whereType<Map>().map((c)=>c['id']).toSet();
  final conflicts=prepared.cards.where((c)=>localIds.contains(c['id'])).length;
  bool replace=false;
  if(conflicts>0){
   final choice=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(t('Bestaande kaarten','Existing cards')),content:Text(t('$conflicts kaarten staan al op dit toestel. Welke versie wil je voor deze kaarten bewaren?','$conflicts cards already exist on this device. Which version should be kept?')),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:Text(t('Huidige bewaren','Keep current'))),FilledButton(onPressed:()=>Navigator.pop(c,true),child:Text(t('Back-up gebruiken','Use backup')))]));
   if(choice==null)return;replace=choice;
  }
  await BackupService.applyRestore(prepared,replaceConflicts:replace);
  if(mounted && BackupService.error==null)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('Kaarten hersteld. Je kunt nu automatische back-up inschakelen.','Cards restored. You can now enable automatic backup.'))));
 }
 @override Widget build(BuildContext context){
  return Scaffold(appBar:AppBar(title:Text(t('Back-up van mijn kaarten','Back up my cards'))),body:ValueListenableBuilder<int>(valueListenable:BackupService.revision,builder:(context,_,child){
   final signedIn=AccountService.currentUser!=null;final busy=BackupService.busy;final available=BackupService.status?['available']==true;
   return ListView(padding:const EdgeInsets.all(20),children:[
    const Icon(Icons.cloud_done_outlined,size:54),const SizedBox(height:16),
    Text(t('Je kaarten terug op een andere telefoon','Your cards on another phone'),style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:10),
    Text(t('Bewaar een versleutelde kopie bij je account. Herstellen werkt op iPhone en Android. Alleen wijzigingen die succesvol zijn geüpload kun je terughalen.','Keep an encrypted copy with your account. Restore on iPhone or Android. Only successfully uploaded changes can be recovered.')),
    if(!signedIn) ...[
     const SizedBox(height:20),FilledButton(onPressed:()async{await Navigator.push(context,MaterialPageRoute(builder:(_)=>const AccountScreen()));await BackupService.refresh();if(mounted)setState((){});},child:Text(t('Inloggen voor back-up','Sign in to back up'))),
    ]else ...[
     const SizedBox(height:16),if(busy)const LinearProgressIndicator(),
     if(!busy && BackupService.status==null)OutlinedButton(onPressed:BackupService.refresh,child:Text(t('Opnieuw verbinden','Reconnect'))),
     if(BackupService.status?['available']==false)Text(message('NOT_AVAILABLE')),
     SwitchListTile(contentPadding:EdgeInsets.zero,title:Text(t('Automatische back-up','Automatic backup')),subtitle:Text(t('Bij wijzigingen, met internet en terwijl de app actief is. Uitschakelen bewaart bestaande back-ups.','After changes, while online and the app is active. Turning off keeps existing backups.')),value:BackupService.enabled,onChanged:busy||!available?null:_enable),
     Text(BackupService.lastSuccess==null?t('Nog geen geslaagde back-up','No successful backup yet'):t('Laatste back-up: ${_date(BackupService.lastSuccess!)}','Last backup: ${_date(BackupService.lastSuccess!)}')),
     if(available)Text(t('${((BackupService.status?['usedBytes']??0)/1000000).toStringAsFixed(2)} van 10 MB gebruikt · maximaal drie versies','${((BackupService.status?['usedBytes']??0)/1000000).toStringAsFixed(2)} of 10 MB used · up to three versions')),
     if(BackupService.error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(message(BackupService.error!),style:TextStyle(color:Theme.of(context).colorScheme.error))),
     const SizedBox(height:12),FilledButton.icon(onPressed:busy||!available||!BackupService.enabled?null:()=>BackupService.upload(),icon:const Icon(Icons.backup_outlined),label:Text(t('Nu back-up maken','Back up now'))),
     const SizedBox(height:20),Text(t('Beschikbare back-ups','Available backups'),style:Theme.of(context).textTheme.titleMedium),
     for(final v in BackupService.versions)ListTile(contentPadding:EdgeInsets.zero,title:Text(_date(v['createdAt'])),subtitle:Text(t('${v['cardCount']} kaarten','${v['cardCount']} cards')),trailing:IconButton(tooltip:t('Herstellen','Restore'),onPressed:busy?null:()=>_restore(v),icon:const Icon(Icons.restore))),
     const SizedBox(height:16),TextButton(onPressed:busy||BackupService.versions.isEmpty?null:()async{if(await _confirm(t('Alle cloudback-ups verwijderen?','Delete all cloud backups?'),t('Alle drie de versies worden definitief verwijderd en automatische back-up gaat uit. Je kaarten op dit toestel blijven staan.','All versions will be permanently deleted and automatic backup will turn off. Cards on this device remain.')))await BackupService.deleteCloud();},child:Text(t('Alle cloudback-ups verwijderen','Delete all cloud backups'))),
    ],
    const SizedBox(height:20),Text(t('Beveiliging: alleen jouw ingelogde account heeft toegang. Voor herstel na telefoonverlies beheert PasKluis de ontsleutelsleutels. Dit is geen end-to-endversleuteling.','Security: only your signed-in account can access your backups. PasKluis manages decryption keys to allow recovery after phone loss. This is not end-to-end encryption.')),
    if(_overview!=null)...[const Divider(),Text(t('Beheer · back-upgebruik','Admin · backup usage'),style:Theme.of(context).textTheme.titleMedium),Text('${_overview!['users']} accounts · ${_overview!['versions']} versions · ${((_overview!['storageBytes']??0)/1000000).toStringAsFixed(2)} MB · ${_overview!['failures']} errors'),Text(t('Capaciteit opnieuw beoordelen bij 50 gebruikers.','Review capacity at 50 users.'))],
   ]);
  }));
 }
 String _date(String value){final d=DateTime.tryParse(value)?.toLocal();if(d==null)return value;return '${d.day.toString().padLeft(2,'0')}-${d.month.toString().padLeft(2,'0')}-${d.year} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';}
}
