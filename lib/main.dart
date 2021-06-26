import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart';

import 'package:telephony/telephony.dart';

import 'package:transp/constants.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

dynamic backgroundMessageHandler(SmsMessage message) async {
  print("Background Message");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox(Constants.boxName);
  Telephony.instance.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        showCupertinoDialog(
          context: navigatorKey.currentContext!,
          builder: (BuildContext context) {
            return AlertDialog(
                title: const Text('Foreground Message : '),
                content: Text('${message.body} ${message.address}'));
          },
        );
      },
      onBackgroundMessage: backgroundMessageHandler);
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
  late Timer _clock;
  late sio.Socket socket;
 

  @override
  void initState(){
    super.initState();
    //askForLocationPermission();
    connectToServer();
  }

  handleMessage(dynamic data) {
    print(data);
  }

  Future askForLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    
    if (!serviceEnabled) {
      return "";
    }

    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return "";
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return "";
    }
    return "";
  }

  void connectToServer() {
    try {
      var box = Hive.box(Constants.boxName);
      var socketURL = box.get(Constants.socketIOStore,
          defaultValue: Constants.defaultsocketURL);
      socket = sio.io(socketURL, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      });

      socket.connect();

      socket.on('connect', (_) {
       
        print('connect: ${socket.id}');
      });
      socket.on('message', handleMessage);
      socket.on('disconnect', (_) {
        print('disconnect');
      });
      socket.on('fromServer', (_) => print(_));
    } catch (e) {
      print(e.toString());
    }
  }

  _sendSocketData() {
    storeLocation();
    var box = Hive.box(Constants.boxName);
    var locationData =
        box.get(Constants.locationStore, defaultValue: '{"locationdump":"{}"}');
    socket.emit("message", locationData);
  }

  _startTimer() {
    const oneSec = const Duration(seconds: 1);
    _clock = Timer.periodic(oneSec, (Timer t) {
      _sendSocketData();
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: const FloatingActionButton(
          onPressed: sendMessagesToServer, child: Icon(Icons.send)),
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: _startTimer,
            icon: const Icon(Icons.bolt),
          ),
           IconButton(
            onPressed: askForLocationPermission,
            icon:const Icon(Icons.hail_rounded),
          ),
          const IconButton(
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
                    onTap: () {
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
    List<SmsMessage> _messages = [];
    if (Platform.isAndroid) {
      _messages = await Telephony.instance.getInboxSms(
          filter: SmsFilter.where(SmsColumn.ADDRESS).equals("MPESA"));
      messages = _messages;
    } else {
      messages = [];
    }
    return _messages;
  }
}

void changeURL() {
  var box = Hive.box(Constants.boxName);
  var _remoteurlController = TextEditingController();
  // ignore: non_constant_identifier_names
  var _IOController = TextEditingController();

  _IOController.value = TextEditingValue(
      text: box.get(Constants.socketIOStore,
          defaultValue: Constants.defaultsocketURL));

  _remoteurlController.value = TextEditingValue(
      text: box.get(Constants.serverUrlStore,
          defaultValue: Constants.defaultUrl));

  showModalBottomSheet<void>(
      isScrollControlled: true,
      context: navigatorKey.currentContext!,
      builder: (BuildContext ctx) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 30,
                right: 30),
            child: SizedBox(
              height: 150,
              child: Center(
                  child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(gapPadding: 2),
                      labelText: 'Enter Remote Server URL',
                      hintText: 'Hope it supports JSON',
                    ),
                    controller: _remoteurlController,
                    onChanged: (String s) {
                      box.put(Constants.serverUrlStore, s);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(gapPadding: 2),
                      labelText: '⚡ Socket URL',
                      hintText: 'socketIo is the way',
                    ),
                    controller: _IOController,
                    onChanged: (String s) {
                      box.put(Constants.socketIOStore, s);
                    },
                  ),
                ],
              )),
            ),
          ),
        );
      });
}

void sendMessagesToServer() async {
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
    var serverUrl =
        box.get(Constants.serverUrlStore, defaultValue: Constants.defaultUrl);
    var response = await post(Uri.parse(serverUrl + "/data"),
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

void sendYourLocation() async {
  try {
    storeLocation();
    var box = Hive.box(Constants.boxName);

    var serverUrl =
        box.get(Constants.serverUrlStore, defaultValue: Constants.defaultUrl);
    var locationData =
        box.get(Constants.locationStore, defaultValue: '{"locationdump":"{}"}');
    var response = await post(Uri.parse(serverUrl + "/location"),
        headers: {
          "Accept": "application/json",
          "Content-type": "application/json",
        },
        body: locationData);
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

void storeLocation() async {
  var box = Hive.box(Constants.boxName);
  bool serviceEnabled;
  LocationPermission permission;
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('Location services are disabled.');
  }
  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    return Future.error('Location permissions are denied');
  }

  if (permission == LocationPermission.deniedForever) {
    return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.');
  }

  Position _l = await Geolocator.getCurrentPosition();
  Map<String, double?> locationRest = {
    "lat": _l.latitude,
    "lon": _l.longitude,
    "alt": _l.altitude,
    "speed": _l.speed,
    "accuracy": _l.accuracy,
    "saccuracy": _l.speedAccuracy,
    "comapss": _l.heading,
  };
  box.put(Constants.locationStore, jsonEncode({"locationdump": locationRest}));
}
