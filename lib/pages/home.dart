import 'package:flutter/material.dart';
import 'package:live_streaming/pages/director.dart';
import 'package:live_streaming/pages/participant.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {

  final _channelName = TextEditingController();
  final _userName = TextEditingController();
  late int uid;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getUserId();
  }

  Future<void> getUserId() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    int? storedUid = preferences.getInt("localUid");
    if(storedUid != null){
      uid = storedUid;
      print("storedUId:  $uid");
    }else{
      int time = DateTime.now().millisecondsSinceEpoch;
      uid = int.parse(time.toString().substring(1, time.toString().length - 3));
      preferences.setInt("localUId", uid);
      print("settingUId: $uid");
    }
  }
  @override
  Widget build(BuildContext context) {


    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/streamer.png"),
            const SizedBox(height: 5,),
            const Text("Multi Streaming with friends"),
            const SizedBox(height: 40,),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
                child: TextField(
                  controller: _userName,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: Colors.grey)
                    ),
                    hintText: "User Name"
                  ),
                )),
            const SizedBox(height: 5,),
            SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                child: TextField(
                  controller: _channelName,
                  decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Colors.grey)
                      ),
                      hintText: "Channel Name"
                  ),
                )),

            TextButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => Participant(userName: _userName.text, channelName: _channelName.text, uid: uid,),));
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Participant  ", style: TextStyle(fontSize: 20),),
                    Icon(Icons.live_tv)
                  ],
                )
            ),
            TextButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => Director(channelName: _channelName.text, uid:uid),));
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Director  ", style: TextStyle(fontSize: 20),),
                    Icon(Icons.cut)
                  ],
                )
            ),
          ],
        ),
      ),
    );
  }
}
