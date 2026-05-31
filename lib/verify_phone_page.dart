import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class VerifyPhonePage extends StatefulWidget {

final String phone;

final String userId;

const VerifyPhonePage({

super.key,

required this.phone,

required this.userId,

});

@override
State<VerifyPhonePage> createState() =>
_VerifyPhonePageState();

}

class _VerifyPhonePageState
extends State<VerifyPhonePage> {

final TextEditingController
_codeController=
TextEditingController();

bool _loading=false;

String? verificationId;

@override
void initState(){

super.initState();

_sendCode();

}

Future<void> _sendCode() async {

    verificationId = null;

    debugPrint(
'VERIFY PAGE SEND CODE CALLED'
);

debugPrint(
'PHONE => ${widget.phone}'
);

await FirebaseAuth.instance.verifyPhoneNumber(

phoneNumber: widget.phone,

verificationCompleted:(credential){},

verificationFailed:(e){

debugPrint(
'PHONE VERIFY FAILED: ${e.code}'
);

debugPrint(
'PHONE VERIFY MESSAGE: ${e.message}'
);

debugPrint(
'PHONE VERIFY FULL: $e'
);

if(mounted){

ScaffoldMessenger.of(context)
.showSnackBar(

SnackBar(

content: Text(

'${e.code}\n${e.message}',

),

),

);

}

},

codeSent:(id,resend){

verificationId=id;

debugPrint(
'CODE SENT'
);

debugPrint(
'VERIFICATION ID = $id'
);

},

codeAutoRetrievalTimeout:(id){

verificationId=id;

debugPrint(
'TIMEOUT ID = $id'
);

},

);

}

Future<void> _verify() async {

if(
verificationId==null ||
_codeController.text.length!=6
)return;

setState(()=>_loading=true);

try{

final credential=

PhoneAuthProvider.credential(

verificationId: verificationId!,

smsCode:
_codeController.text.trim(),

);

await FirebaseAuth.instance
.signInWithCredential(
credential,
);

final authUser =
FirebaseAuth.instance.currentUser!;

await FirebaseFirestore.instance
.collection('users')
.doc(authUser.uid)
.set({

'uid': authUser.uid,

'phone': widget.phone,

'phoneVerified': true,

'createdAt':
FieldValue.serverTimestamp(),

'username': '',

'email': '',

},

SetOptions(
merge:true,
),
);

await FirebaseFirestore.instance
.collection('users')
.doc(authUser.uid)
.set({

'phone':widget.phone,

'phoneVerified':true,

'phoneVerifiedAt':
FieldValue.serverTimestamp(),

},

SetOptions(
merge:true,
),

);

if(!mounted)return;

Navigator.pop(
context,
true,
);

}catch(e){

ScaffoldMessenger.of(context)
.showSnackBar(

SnackBar(
content: Text(
e.toString(),
),
),

);

}

setState(()=>_loading=false);

}

@override
Widget build(BuildContext context){

return Scaffold(

body: Container(

decoration:
const BoxDecoration(

gradient:
LinearGradient(

colors:[
Colors.pink,
Colors.pinkAccent
],

begin:
Alignment.topLeft,

end:
Alignment.bottomRight,

),

),

child: Center(

child: SingleChildScrollView(

padding:
const EdgeInsets.all(16),

child: Column(

mainAxisAlignment:
MainAxisAlignment.center,

children:[

Text(

"Verify Phone",

style:
GoogleFonts.dancingScript(

fontSize:32,

fontWeight:
FontWeight.w700,

color:
Colors.white,

),

),

const SizedBox(
height:20,
),

Text(

"Enter code sent to ${widget.phone}",

textAlign:
TextAlign.center,

style:
GoogleFonts.poppins(

color:
Colors.white70,

fontSize:16,

),

),

const SizedBox(
height:25,
),

TextField(

controller:
_codeController,

keyboardType:
TextInputType.number,

maxLength:6,

style:
const TextStyle(
color: Colors.black,
),

decoration:
InputDecoration(

counterText:"",

filled:true,

fillColor:
Colors.white24,

labelText:
"Code",

labelStyle:
const TextStyle(
color: Colors.black54,
),

border:
OutlineInputBorder(

borderRadius:
BorderRadius.circular(
20,
),

borderSide:
BorderSide.none,

),

),

),

const SizedBox(
height:25,
),

SizedBox(

width:150,

height:55,

child:

ElevatedButton(

onPressed:
_loading
?null
:_verify,

style:
ElevatedButton.styleFrom(

backgroundColor:
Colors.amber,

foregroundColor:
Colors.black,

shape:
RoundedRectangleBorder(

borderRadius:
BorderRadius.circular(
18,
),

),

),

child:

_loading

?const SizedBox(

height:24,

width:24,

child:

CircularProgressIndicator(

strokeWidth:3,

color:Colors.black,

),

)

:const Text(

"Verify",

style:

TextStyle(

fontSize:18,

fontWeight:
FontWeight.bold,

),

),

),

),

const SizedBox(
height:16,
),

TextButton(

onPressed: () async {

await _sendCode();

if(!mounted)return;

ScaffoldMessenger.of(context)
.showSnackBar(

const SnackBar(

content:
Text(
'New code sent',
),

),

);

},

child:

const Text(

"Resend Code",

style:

TextStyle(

color:
Colors.white,

fontSize:16,

fontWeight:
FontWeight.w600,

),

),

),

],

),

),

),

),

);

}

}