import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';

import 'package:telephony/telephony.dart';

void main() {
  runApp(const MyApp());
}

final navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
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
  void initState() async {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        floatingActionButton: const FloatingActionButton(
            onPressed: sendMessagesToServer, child: Icon(Icons.send)),
        appBar: AppBar(
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
        ));
  }

  Future<List<SmsMessage>> fetchSMS() async {
    messages = await Telephony.instance.getInboxSms(
        filter: SmsFilter.where(SmsColumn.ADDRESS)
            .equals("MPESA")
            .or(SmsColumn.ADDRESS)
            .equals("Equity Bank")
            .or(SmsColumn.ADDRESS)
            .equals("Safaricom"));

    return messages;
  }
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
    var response = await post(Uri.parse("http://192.168.0.26:9000/data"),
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
