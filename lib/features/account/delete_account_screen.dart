import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../data/services/account_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/supabase_service.dart';

class DeleteAccountScreen extends StatefulWidget {
 const DeleteAccountScreen({super.key});
 @override State<DeleteAccountScreen> createState()=>_DeleteAccountScreenState();
}
class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
 final _password=TextEditingController();
 bool _confirmed=false,_eraseLocal=false,_busy=false;
 String? _error;
 @override void dispose(){_password.dispose();super.dispose();}
 Future<void> _delete() async {
  if(!_confirmed||_password.text.isEmpty||_busy)return;
  setState((){_busy=true;_error=null;});
  try {
   final response=await SupabaseService.client!.functions.invoke('delete-account',body:{'password':_password.text,'confirm':'DELETE_MY_ACCOUNT'});
   if(response.data is! Map||response.data['deleted']!=true)throw StateError('Deletion failed');
   if(_eraseLocal){for(final key in StorageService.cardsBox.keys.toList()){await StorageService.deleteCard(key);}}
   await AccountService.signOut(releaseDevice:false);
   if(mounted){Navigator.of(context).popUntil((route)=>route.isFirst);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(L10n.current.accountDeleted)));}
  }catch(_){if(mounted)setState(()=>_error=L10n.current.accountDeletionFailed);}
  finally{if(mounted)setState(()=>_busy=false);}
 }
 @override Widget build(BuildContext context){
  L10n.watch(context);
  return Scaffold(appBar:AppBar(title:Text(L10n.current.deleteAccount)),body:SafeArea(child:ListView(padding:const EdgeInsets.all(24),children:[
   const Icon(Icons.person_remove_outlined,size:56,color:Color(0xFFD51B46)),const SizedBox(height:20),
   Text(L10n.current.deleteAccountExplanation,style:const TextStyle(height:1.5)),const SizedBox(height:20),
   TextField(controller:_password,obscureText:true,autocorrect:false,enableSuggestions:false,decoration:InputDecoration(labelText:L10n.current.password,border:const OutlineInputBorder()),onChanged:(_)=>setState((){})),
   CheckboxListTile(value:_eraseLocal,onChanged:_busy?null:(v)=>setState(()=>_eraseLocal=v??false),title:Text(L10n.current.alsoDeleteLocalCards),contentPadding:EdgeInsets.zero),
   CheckboxListTile(value:_confirmed,onChanged:_busy?null:(v)=>setState(()=>_confirmed=v??false),title:Text(L10n.current.confirmDeleteAccount),contentPadding:EdgeInsets.zero),
   if(_error!=null)Padding(padding:const EdgeInsets.only(bottom:16),child:Text(_error!,style:const TextStyle(color:Colors.red))),
   FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:const Color(0xFFD51B46)),onPressed:_confirmed&&_password.text.isNotEmpty&&!_busy?_delete:null,icon:_busy?const SizedBox.square(dimension:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.delete_forever),label:Text(L10n.current.deleteAccount)),
  ])));
 }
}
