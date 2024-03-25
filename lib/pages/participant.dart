import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_rtm/agora_rtm.dart';
import 'package:flutter/material.dart';
import 'package:live_streaming/models/users.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/constants.dart';
import '../utils/message.dart';

class Participant extends StatefulWidget {
   String userName;
   String channelName;
   int uid;
  Participant({super.key, required this.userName, required this.channelName, required this.uid});

  @override
  State<Participant> createState() => _ParticipantState();
}

class _ParticipantState extends State<Participant> {

  String token = "";
  List<AgoraUser> _users = [];
  late RtcEngine _engine;
  AgoraRtmClient? _client;
  AgoraRtmChannel? _channel;
  bool muted = false;
  bool videoDisabled = false;
  bool localUserActive = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    generateToken();
    initializeAgora();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _users.clear();
    _engine.leaveChannel();
    _engine.release();
    _channel?.leave();
    _client?.logout();
    _client?.release();
  }

  generateToken() async {
    print("#################################################################################################################");
    final res = await http.get(Uri.parse("https://golang-on-koyeb-student232.koyeb.app/rtc/${widget.channelName}/publisher/userAccount/${widget.uid}/"));
    print(jsonDecode(res.body)["rtcToken"]);
    token = jsonDecode(res.body)["rtcToken"];
    print("#################################################################################################################");

  }

  Future<void> initializeAgora() async {
    await [Permission.microphone, Permission.camera].request();
    _client = await AgoraRtmClient.createInstance(appId);
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(appId: appId, channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,));
    await _engine.enableVideo();
    await _engine.muteLocalAudioStream(true);
    await _engine.muteLocalVideoStream(true);
    await _engine.setChannelProfile(ChannelProfileType.channelProfileLiveBroadcasting);
    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    // Callbacks for the RTC Engine


    _engine.registerEventHandler(
      RtcEngineEventHandler(

        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("local user ${connection.localUid} joined");
          setState(() {
            int randomColor = (Random().nextDouble() * 0xFFFFFFFF).toInt();
            Map<String, String> name = {
              'key': 'name',
              'value': widget.userName,
            };
            Map<String, String> color = {
              'key': 'color',
              'value': randomColor.toString(),
            };
            _client!.addOrUpdateLocalUserAttributes2([RtmAttribute.fromJson(name),RtmAttribute.fromJson(color)]);
          });
          if (widget.uid != connection.localUid) {
            throw ("How can this happen?!?");
          }
        },

        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("remote user $remoteUid joined");
          setState(() {
            // _remoteUid = remoteUid;
          });
        },

        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("remote user $remoteUid left channel");
          setState(() {
            // _remoteUid = null;
          });
        },

        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          debugPrint('[onTokenPrivilegeWillExpire] connection: ${connection.toJson()}, token: $token');
          },

        onLeaveChannel: (connection, stats) => setState(() {
          _users.clear();
        })
      ),
    );


    // Callbacks for RTM Client

    _client?.onMessageReceived = (RtmMessage message, String peerId){
      debugPrint("Peer msg: $peerId, msg: ${message.messageType} ${message.text}");
    };

    _client?.onConnectionStateChanged2 = (RtmConnectionState state, RtmConnectionChangeReason reason) {
          debugPrint('Connection state changed: $state, reason: $reason');
      if (state == RtmConnectionState.aborted) {
        _client?.logout();

        debugPrint('Logout');
          // _isLogin = false;
      }
    };


    // join RTM and RTC Channels
    await _client?.login(null, widget.uid.toString());
    _channel = await _client?.createChannel(widget.channelName);
    _channel?.join();

    await _engine.joinChannel(token: token, channelId: widget.channelName, uid: widget.uid, options: const ChannelMediaOptions());


    // Callbacks for RTM Channel
    _channel?.onMemberJoined = (RtmChannelMember member) {
      debugPrint('Member joined: ${member.userId}, channel: ${member.channelId}');
    };

    _channel?.onMemberLeft = (RtmChannelMember member) {
      debugPrint('Member left: ${member.userId}, channel: ${member.channelId}');
    };

    _channel?.onMessageReceived = (RtmMessage message, RtmChannelMember member) {
      debugPrint("member id: ${member.userId}, msg: ${message.messageType} ${message.text}");
      List<String> parsedMessage = message.text.split(" ");
      switch (parsedMessage[0]) {
        case "mute":
          if (parsedMessage[1] == widget.uid.toString()) {
            setState(() {
              muted = true;
            });
            _engine.muteLocalAudioStream(true);
          }
          break;
        case "unmute":
          if (parsedMessage[1] == widget.uid.toString()) {
            setState(() {
              muted = false;
            });
            _engine.muteLocalAudioStream(false);
          }
          break;
        case "disable":
          if (parsedMessage[1] == widget.uid.toString()) {
            setState(() {
              videoDisabled = true;
            });
            _engine.muteLocalVideoStream(true);
          }
          break;
        case "enable":
          if (parsedMessage[1] == widget.uid.toString()) {
            setState(() {
              videoDisabled = false;
            });
            _engine.muteLocalVideoStream(false);
          }
          break;
        case "activeUsers":
          setState(() {
            _users = Message().parseActiveUsers(uids: parsedMessage[1]);
          });
          break;
        case "isActiveMuted":
          print("is Active muted");
          if (parsedMessage[1] == widget.uid.toString()) {
            setState(() {
              muted = !muted;
            });
            _engine.muteLocalAudioStream(muted);
          }
        case "isActiveDisabled":
          print(muted.toString());
          if (parsedMessage[1] == widget.uid.toString()) {
            setState(() {
              videoDisabled = !videoDisabled;
            });
            _engine.muteLocalVideoStream(videoDisabled);
          }
        default:
      }

    };




  }

  void _onCallEnd(BuildContext context) {
    Navigator.pop(context);
  }

  void _onToggleMute(uid) {
    _channel?.sendMessage2(RtmMessage.fromText("isActiveMuted ${uid}"));
  }

  void _onToggleVideoDisabled(uid) {
    _channel?.sendMessage2(RtmMessage.fromText("isActiveDisabled ${uid}"));
  }

  void _onSwitchCamera() {
    _engine.switchCamera();
  }

  List<Widget> _getRenderViews() {
    final List<Widget> list = [];
    bool checkIfLocalActive = false;
    for (int i = 0; i < _users.length; i++) {
      if (_users[i].uid == widget.uid) {
        list.add(Stack(children: [
          AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: _engine,
              canvas: const VideoCanvas(uid: 0),
            ),
          ),
          Align(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(borderRadius: BorderRadius.only(topLeft: Radius.circular(10)), color: Colors.white),
              child: Text(widget.userName),
            ),
            alignment: Alignment.bottomRight,
          ),
        ]));
        checkIfLocalActive = true;
      } else {
        list.add(Stack(children: [
          AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _engine,
              canvas: VideoCanvas(uid: _users[i].uid),
              connection: RtcConnection(channelId: widget.channelName),
            ),
          ),
          Align(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(borderRadius: BorderRadius.only(topLeft: Radius.circular(10)), color: Colors.white),
              child: Text(_users[i].name ?? "name error"),
            ),
            alignment: Alignment.bottomRight,
          ),
        ]));
      }
    }

    if (checkIfLocalActive) {
      setState(() {
        localUserActive = true;
      });
    } else {
      setState(() {
        localUserActive = false;
      });
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Center(
        child: Stack(
          children: [
            BroadcastView(),
            ToolBar(widget.uid),
          ],
        ),
      ),
    );
  }

  Widget BroadcastView() {
      final views = _getRenderViews();
      switch (views.length) {
        case 0:
          return const Center(
            child: Text("Nothing to see here"),
          );
        case 1:
          return Container(
              child: Column(
                children: <Widget>[
                  _expandedVideoView([views[0]])
                ],
              ));
        case 2:
          return Container(
              child: Column(
                children: <Widget>[
                  _expandedVideoView([views[0]]),
                  _expandedVideoView([views[1]])
                ],
              ));
        case 3:
          return Container(
              child: Column(
                children: <Widget>[_expandedVideoView(views.sublist(0, 2)), _expandedVideoView(views.sublist(2, 3))],
              ));
        case 4:
          return Container(
              child: Column(
                children: <Widget>[_expandedVideoView(views.sublist(0, 2)), _expandedVideoView(views.sublist(2, 4))],
              ));
        default:
      }
      return Container();
    }

  Widget _expandedVideoView(List<Widget> views) {
    final wrappedViews = views.map<Widget>((view) => Expanded(child: Container(child: view))).toList();
    return Expanded(
      child: Row(
        children: wrappedViews,
      ),
    );
  }

  Widget ToolBar(uid){
    return Container(
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          localUserActive
              ? RawMaterialButton(
            onPressed: (){
              _onToggleMute(uid);
    },
            shape: const CircleBorder(),
            elevation: 2.0,
            fillColor: muted ? Colors.blueAccent : Colors.white,
            padding: const EdgeInsets.all(12.0),
            child: Icon(
              muted ? Icons.mic_off : Icons.mic,
              color: muted ? Colors.white : Colors.blueAccent,
              size: 20.0,
            ),
          )
              : const SizedBox(),
          RawMaterialButton(
            onPressed: () => _onCallEnd(context),
            shape: const CircleBorder(),
            elevation: 2.0,
            fillColor: Colors.redAccent,
            padding: const EdgeInsets.all(15.0),
            child: const Icon(
              Icons.call_end,
              color: Colors.white,
              size: 35.0,
            ),
          ),
         localUserActive
              ? RawMaterialButton(
            onPressed: (){
              _onToggleVideoDisabled(uid);
            },
            shape: const CircleBorder(),
            elevation: 2.0,
            fillColor: videoDisabled ? Colors.blueAccent : Colors.white,
            padding: const EdgeInsets.all(12.0),
            child: Icon(
              videoDisabled ? Icons.videocam_off : Icons.videocam,
              color: videoDisabled ? Colors.white : Colors.blueAccent,
              size: 20.0,
            ),
          )
              : const SizedBox(),
          localUserActive
              ? RawMaterialButton(
            onPressed: _onSwitchCamera,
            shape: const CircleBorder(),
            elevation: 2.0,
            fillColor: Colors.white,
            padding: const EdgeInsets.all(12.0),
            child: const Icon(
              Icons.switch_camera,
              color: Colors.blueAccent,
              size: 20.0,
            ),
          )
              : const SizedBox(),
        ],
      ),
    );
  }



}







