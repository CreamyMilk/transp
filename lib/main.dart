import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart';

import 'package:telephony/telephony.dart';
import 'package:location/location.dart';
import 'package:transp/constants.dart';

dynamic backgroundMessageHandler(SmsMessage message) async {
  print("Background Message");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox(Constants.boxName);
  Location location =  Location();
  location.enableBackgroundMode(enable: true);
  PermissionStatus localperm = await location.hasPermission();
  if(localperm == PermissionStatus.granted){
    location.onLocationChanged.listen((LocationData currentLocation) {
      //Send to Server if possible
    });
  }
  Telephony.instance.listenIncomingSms(
		onNewMessage: (SmsMessage message) {
		 showCupertinoDialog(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) {
        return AlertDialog(
            title: const Text('Foreground Message : '), content: Text('${message.body} ${message.address}'));
      },
    );
		},
		onBackgroundMessage: backgroundMessageHandler
	);
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
          primarySwatch: Colors.teal,
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
              onPressed: sendYourLocation,
              icon: Icon(Icons.location_on),
            ),
            IconButton(
              onPressed: changeURL,
              icon: Icon(Icons.web_stories),
            ),
          ],
          title: const Text("👀 List"),
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
                      onTap:(){
                        showCupertinoDialog(
                          context: navigatorKey.currentContext!,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('::::   🦀    ::::'),
                              content: Text(messages[index].body ?? ""),
                              );
                          },
                        );
                      },
                      leading: const Icon(
                        Icons.markunread,
                        color: Colors.teal,
                      ),
                      title: Text(messages[index].address ?? ""),
                      subtitle: Text(messages[index].body ?? "", maxLines: 2),
                    ),
                  );
                });
          },
        ),
    );
  }

  Future<List<SmsMessage>> fetchSMS() async {
    if(Platform.isAndroid){
    messages = await Telephony.instance.getInboxSms(
        filter: SmsFilter.where(SmsColumn.ADDRESS)
            .equals("MPESA"));
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
    isScrollControlled:true,
    context:navigatorKey.currentContext!,
    builder: (BuildContext ctx){
      return SingleChildScrollView(
        child:Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom,left: 30,right:30),
        child:SizedBox(
          height: 100,
          child:Center(
          child:TextField(
            decoration: const InputDecoration(
                  border: OutlineInputBorder(gapPadding: 2),
                  labelText: 'Enter Remote Server URL',
                  hintText: 'Hope it supports JSON',
                ),
            controller:_controler,
           
            onChanged: (String s){
               box.put(Constants.serverUrlStore,s);
            },
          )),
        ),),
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
      "MessageSubject": message.subject ?? "o",
      "messagetxt": message.body,
    };
    dataBlob.add(messageDestructure);
  }
  
  try {
    var box = Hive.box(Constants.boxName);
    var serverUrl = box.get(Constants.serverUrlStore,defaultValue:Constants.defaultUrl);
    var response = await post(Uri.parse(serverUrl+"/data"),
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
;
    showCupertinoDialog(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) {
        return AlertDialog(
            title: const Text('Error Sending : '), content: Text('$error'));
      },
    );
  }
}



void sendYourLocation() async {
  Location location =  Location();
  bool _serviceEnabled;
  PermissionStatus _permissionGranted;
  LocationData _l;
  _serviceEnabled = await location.serviceEnabled();
  if (!_serviceEnabled) {
    _serviceEnabled = await location.requestService();
    if (!_serviceEnabled) {
      return;
    }
  }
  _permissionGranted = await location.hasPermission();
  if (_permissionGranted == PermissionStatus.denied) {
    _permissionGranted = await location.requestPermission();
    if (_permissionGranted != PermissionStatus.granted) {
      return;
    }
  }

  _l = await location.getLocation(); 
   
    Map<String, double?> locationRest = {
      "lat" : _l.latitude ?? 999,
      "lon": _l.longitude ?? 999,
      "alt": _l.altitude  ?? 999,
      "speed": _l.speed ?? 999,
      "accuracy" : _l.accuracy ??999,
      "saccuracy": _l.speedAccuracy ?? 999,
    };

  
  try {
    var box = Hive.box(Constants.boxName);
    var serverUrl = box.get(Constants.serverUrlStore,defaultValue:Constants.defaultUrl);
    var response = await post(Uri.parse(serverUrl+"/location"),
        headers: {
          "Accept": "application/json",
          "Content-type": "application/json",
        },
        body: jsonEncode({"localdump": locationRest}));
    var jsonresponse = json.decode(response.body);

    showCupertinoDialog(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) {
        return AlertDialog(
            title: const Text('Sent Location  : '),
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
