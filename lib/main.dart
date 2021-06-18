import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart';

import 'package:telephony/telephony.dart';
import 'package:transp/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox(Constants.boxName);
  runApp(const MyApp());
}
final navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Tranpsport Stuff',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        navigatorKey: navigatorKey,
        home: const MyHomePage());
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<SmsMessage> messages = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        floatingActionButton: const FloatingActionButton(
            onPressed: sendMessagesToServer, child: Icon(Icons.send)),
        appBar: AppBar(
          actions:const [
            IconButton(
              onPressed: changeURL,
              icon: Icon(Icons.web_stories),
            ),
          ],
          title: const Text("Messages List"),
        ),
        body: FutureBuilder(
          future: fetchSMS(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Text("Error");
            return ListView.separated(
                separatorBuilder: (context, index) => const Divider(
                      color: Colors.black,
                    ),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ListTile(
                      leading: const Icon(
                        Icons.markunread,
                        color: Colors.pink,
                      ),
                      title: Text(messages[index].address ?? ""),
                      subtitle: Text(messages[index].body ?? "", maxLines: 2),
                    ),
                  );
                });
          },
        ),);
  }

  Future<List<SmsMessage>> fetchSMS() async {
    if(Platform.isAndroid){
    messages = await Telephony.instance.getInboxSms(
        filter: SmsFilter.where(SmsColumn.ADDRESS)
            .equals("MPESA")
            .or(SmsColumn.ADDRESS)
            .equals("Equity Bank")
            .or(SmsColumn.ADDRESS)
            .equals("Safaricom"));
    }else{
      messages = [];
    }
    return messages;
  }
}

void changeURL() {
  var box = Hive.box(Constants.boxName);
  var _controler = TextEditingController();
  _controler.value = TextEditingValue(text:box.get(Constants.serverUrlStore,defaultValue:Constants.defaultUrl));
  showModalBottomSheet<void>(
    context:navigatorKey.currentContext!,
    builder: (BuildContext ctx){
      return SizedBox(
        width:100,
        height: 500,
        child:Center(child:TextField(
          controller:_controler,
          onChanged: (String s){
     box.put(Constants.serverUrlStore,s);
          },
  
        )),
      );
    }
    );
 
}
void sendMessagesToServer() async {
  //get messages
  List<Map<String, dynamic>> dataBlob = [];

  final messagesDump = await Telephony.instance
      .getInboxSms(filter: SmsFilter.where(SmsColumn.ADDRESS).equals("MPESA"));
  for (SmsMessage message in messagesDump) {
    Map<String, String?> messageDestructure = {
      "subscriptionid": message.subscriptionId.toString(),
      "messageTimestamp": message.date.toString(),
      "thread": message.threadId.toString(),
      "phoneNumber": message.address,
      "MessageSubject": message.subject,
      "messagetxt": message.body,
    };
    dataBlob.add(messageDestructure);
  }
  try {
    var box = Hive.box(Constants.boxName);
    var serverUrl = box.get(Constants.serverUrlStore);
    var response = await post(Uri.parse(serverUrl),
        headers: {
          "Accept": "application/json",
          "Content-type": "application/json",
        },
        body: jsonEncode({"messageDump": dataBlob}));
    var jsonresponse = json.decode(response.body);

    showCupertinoDialog(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) {
        return AlertDialog(
            title: const Text('Sent Message Dump: '),
            content: Text('$jsonresponse'));
      },
    );
  } catch (error) {
    showCupertinoDialog(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) {
        return AlertDialog(
            title: const Text('Error Sending : '), content: Text('$error'));
      },
    );
  }
}
