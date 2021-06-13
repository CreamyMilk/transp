import 'package:flutter/material.dart';

import 'package:telephony/telephony.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage());
  }
}
class MyHomePage extends StatefulWidget {
  const MyHomePage({ Key? key }) : super(key: key);
  
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<SmsMessage> messages = [];
  
  @override
  void initState()async {
    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:AppBar(
        title:const Text( "Messages LIst"),
      ),
      body: FutureBuilder(
        future: fetchSMS() ,
        builder: (context, snapshot)  {
        if(snapshot.hasError) return const Text("Error");
        return ListView.separated(
            separatorBuilder: (context, index) => const Divider(
              color: Colors.black,
            ),
            itemCount: messages.length,
          itemBuilder: (context,index){
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListTile(
              leading: const Icon(Icons.markunread,color: Colors.pink,),
              title: Text(messages[index].address ?? ""),
              subtitle: Text(messages[index].body ?? "",maxLines:2),
            ),
          );
        });
      },)
    );
  }

  Future<List<SmsMessage>> fetchSMS() async {
    messages = await Telephony.instance.getInboxSms(
     filter:SmsFilter.where(SmsColumn.ADDRESS)
				 .equals("MPESA")
				 .or(SmsColumn.ADDRESS)
         .equals("Equity Bank")
         .or(SmsColumn.ADDRESS)
         .equals("Safaricom")
    );
    return messages;
  }}