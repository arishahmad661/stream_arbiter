import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_rtm/agora_rtm.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_streaming/models/director.dart';
import 'package:live_streaming/models/users.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/constants.dart';
import '../utils/message.dart';


final directorController = StateNotifierProvider.autoDispose<DirectorController, DirectorModel>((ref) => DirectorController(DirectorModel()));

class DirectorController extends StateNotifier<DirectorModel> {
  DirectorController(super.state);

  Future _initialize() async {
    AgoraRtmClient _client = await AgoraRtmClient.createInstance(appId);

    RtcEngine _engine = createAgoraRtcEngine();

    await _engine.initialize(RtcEngineContext(appId: appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,));
    state = DirectorModel(engine: _engine, client: _client);
  }

  generateToken(channelName, uid) async {
    final res = await http.get(Uri.parse(
        "https://golang-on-koyeb-student232.koyeb.app/rtc/${channelName}/publisher/userAccount/${uid}/"));
    print(jsonDecode(res.body)["rtcToken"]);
    return jsonDecode(res.body)["rtcToken"].toString();
  }

  Future joinCall({required String channelName, required int uid}) async {
    await _initialize();
    String token = await generateToken(channelName, uid);
    await [Permission.microphone, Permission.camera].request();

    // Callbacks for the RTC Engine
    state.engine?.registerEventHandler(
      RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint("Director ${connection.localUid} joined");
          },

          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint("remote user $remoteUid joined");
            addUserToLobby(uid: remoteUid);
          },

          // onAudioDeviceStateChanged: (deviceId, deviceType, deviceState) {
          //   if(deviceState == RemoteAudioState.remoteAudioStateDecoding){
          //     updateUserAudio(uid: uid, muted: false);
          //   }
          //   else if(deviceState == RemoteAudioState.remoteAudioStateStopped){
          //     updateUserAudio(uid: uid, muted: true);
          //   }
          // },

          // onVideoDeviceStateChanged: (deviceId, deviceType, deviceState) {
          //   if(deviceState == RemoteVideoState.remoteVideoStateDecoding){
          //     updateUserVideo(uid: uid, videoDisabled: false);
          //   }
          //   else if(deviceState == RemoteVideoState.remoteVideoStateStopped){
          //     updateUserVideo(uid: uid, videoDisabled: true);
          //   }
          // },

          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint("remote user $remoteUid left channel");
          },

          onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
            debugPrint(
                '[onTokenPrivilegeWillExpire] connection: ${connection.toJson()}, token: $token');
          },

          onLeaveChannel: (connection, stats) { print("Channel Left");}

      ),
    );

    await state.engine?.enableVideo();
    await state.engine?.setChannelProfile(
        ChannelProfileType.channelProfileLiveBroadcasting);
    await state.engine?.setClientRole(
        role: ClientRoleType.clientRoleBroadcaster);


    // Callbacks for RTM Client

    state.client?.onMessageReceived = (RtmMessage message, String peerId) {
      debugPrint(
          "Peer msg: $peerId, msg: ${message.messageType} ${message.text}");
    };

    state.client?.onConnectionStateChanged2 = (RtmConnectionState st, RtmConnectionChangeReason reason) {
      debugPrint('Connection state changed: $st, reason: $reason');
      if (st == RtmConnectionState.aborted) {
        state.client?.logout();
        debugPrint('Logout');
      }
    };


    // join RTM and RTC Channels
    await state.client?.login(null, uid.toString());
    state = state.copyWith(channel: await state.client?.createChannel(channelName));
    state.channel?.join();

    await state.engine?.joinChannel(token: token,
        channelId: channelName,
        uid: uid,
        options: ChannelMediaOptions());


    // Callbacks for RTM Channel
    state.channel?.onMemberJoined = (RtmChannelMember member) {
      debugPrint(
          'Member joined: ${member.userId}, channel: ${member.channelId}');

    };

    state.channel?.onMemberLeft = (RtmChannelMember member) {
      debugPrint('Member left: ${member.userId}, channel: ${member.channelId}');
    };

    state.channel?.onMessageReceived = (RtmMessage message, RtmChannelMember member) {
      debugPrint("User id: ${member.userId}, msg: ${message.messageType} ${message.text}");
      List<String> parsedMessage = message.text.split(" ");

      if(parsedMessage[0].toString() == "isActiveMuted") {
        Set<AgoraUser> _temp = state.activeUsers;
        print(parsedMessage[1]);
        for (int i = 0; i < _temp.length; i++) {
          print(_temp.elementAt(i).uid);
          if (_temp.elementAt(i).uid.toString() == parsedMessage[1].toString()) {
            if (_temp.elementAt(i).muted == false) {
              state.channel?.sendMessage2(RtmMessage.fromText("isActiveMuted ${parsedMessage[1]}"));

              print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%");
              print(state.activeUsers.elementAt(i).didUserMuted.toString());
              print(state.activeUsers.elementAt(i).didUserDisabled.toString());
              print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%");

              bool checkMic = state.activeUsers.elementAt(i).didUserMuted;
              bool checkVideo = state.activeUsers.elementAt(i).didUserDisabled;

              AgoraUser _tempUser = state.activeUsers.elementAt(i);
              Set<AgoraUser> _tempSet = state.activeUsers;

              _tempSet.remove(_tempUser);
              _tempSet.add(_tempUser.copyWith(didUserMuted: !checkMic, didUserDisabled: checkVideo));
              state = state.copyWith(activeUsers: _tempSet);

              print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%");
              print(state.activeUsers.elementAt(state.activeUsers.length - 1).didUserMuted.toString());
              print(state.activeUsers.elementAt(state.activeUsers.length - 1).didUserDisabled.toString());
              print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%");

            }
            break;
          }
        }
      }
      else if(parsedMessage[0].toString() == "isActiveDisabled"){
        Set<AgoraUser> _temp = state.activeUsers;
        print(_temp.elementAt(0).uid);

        print(parsedMessage[1]);
        for (int i = 0; i < _temp.length; i++) {
          print(_temp
              .elementAt(i)
              .uid);

          if (_temp.elementAt(i).uid.toString() == parsedMessage[1].toString()) {
            if (_temp.elementAt(i).videoDisabled == false) {
              state.channel?.sendMessage2(RtmMessage.fromText("isActiveDisabled ${parsedMessage[1]}"));

              print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%");
              print(state.activeUsers.elementAt(i).didUserMuted.toString());
              print(state.activeUsers.elementAt(i).didUserDisabled.toString());
              print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%");

              bool checkMic = state.activeUsers.elementAt(i).didUserMuted;
              bool checkVideo = state.activeUsers.elementAt(i).didUserDisabled;

              AgoraUser _tempUser = state.activeUsers.elementAt(i);
              Set<AgoraUser> _tempSet = state.activeUsers;

              _tempSet.remove(_tempUser);
              _tempSet.add(_tempUser.copyWith(didUserMuted: checkMic, didUserDisabled: !checkVideo));
              state = state.copyWith(activeUsers: _tempSet);

              print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%");
              print(state.activeUsers.elementAt(state.activeUsers.length - 1).didUserMuted.toString());
              print(state.activeUsers.elementAt(state.activeUsers.length - 1).didUserDisabled.toString());
              print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%");


            }
            break;
          }
        }
      }

    };
  }

  Future leaveCall() async {
    state.engine?.leaveChannel();
    state.engine?.release();
    state.channel?.leave();
    state.client?.logout();
    state.client?.release();
  }

  Future addUserToLobby({required int uid}) async {
    var userAttributes = await state.client?.getUserAttributes2(uid.toString());
    state = state.copyWith(lobbyUsers: {
      ...state.lobbyUsers,
      AgoraUser(uid: uid,
          muted: true,
          videoDisabled: true,
          name: userAttributes?[0].value,
          backgroundColor: Color(int.parse(userAttributes![1].value)))
    });
    state.channel?.sendMessage2(RtmMessage.fromText(Message().sendActiveUsers(activeUsers: state.activeUsers)));
  }

  Future removeUser({required int uid}) async {
    Set<AgoraUser> _temp = state.activeUsers;
    Set<AgoraUser> _tempLobby = state.lobbyUsers;

    for (int i = 0; i < _temp.length; i++) {
      if (_temp
          .elementAt(i)
          .uid == uid) {
        _temp.remove(_temp.elementAt(i));
      }
    }
    for (int i = 0; i < _tempLobby.length; i++) {
      if (_tempLobby
          .elementAt(i)
          .uid == uid) {
        _tempLobby.remove(_tempLobby.elementAt(i));
      }
    }
    state = state.copyWith(activeUsers: _temp, lobbyUsers: _tempLobby);

    state.channel?.sendMessage2(RtmMessage.fromText(Message().sendActiveUsers(activeUsers: state.activeUsers)));

  }

  Future promoteToActiveUser({required int uid}) async {
    Set<AgoraUser> _tempLobby = state.lobbyUsers;
    Color? tempColor;
    String? tempName;
    for (int i = 0; i < _tempLobby.length; i++) {
      if (_tempLobby.elementAt(i).uid == uid) {
        tempColor = _tempLobby.elementAt(i).backgroundColor;
        tempName = _tempLobby.elementAt(i).name;
        _tempLobby.remove(_tempLobby.elementAt(i));
      }
    }
    state = state.copyWith(activeUsers: {
      ...state.activeUsers,
      AgoraUser(
        uid: uid,
        backgroundColor: tempColor,
        name: tempName,
      )
    }, lobbyUsers: _tempLobby);

    state.channel?.sendMessage2(RtmMessage.fromText("unmute ${uid}"));
    state.channel?.sendMessage2(RtmMessage.fromText("enable ${uid}"));
    state.channel?.sendMessage2(RtmMessage.fromText(Message().sendActiveUsers(activeUsers: state.activeUsers)));

  }

  Future demoteToLobbyUser({required int uid}) async {
    Set<AgoraUser> _temp = state.activeUsers;
    Color? tempColor;
    String? tempName;
    for (int i = 0; i < _temp.length; i++) {
      if (_temp.elementAt(i).uid == uid) {
        tempColor = _temp.elementAt(i).backgroundColor;
        tempName = _temp.elementAt(i).name;
        _temp.remove(_temp.elementAt(i));
      }
    }
    state = state.copyWith(activeUsers: _temp, lobbyUsers: {
      ...state.lobbyUsers,
      AgoraUser(
        uid: uid,
        videoDisabled: true,
        muted: true,
        backgroundColor: tempColor,
        name: tempName,
      )
    });
    state.channel?.sendMessage2(RtmMessage.fromText("mute ${uid}"));
    state.channel?.sendMessage2(RtmMessage.fromText("disable ${uid}"));
    state.channel?.sendMessage2(RtmMessage.fromText(Message().sendActiveUsers(activeUsers: state.activeUsers)));

  }

  // Future updateUserAudio({required int uid , required bool muted}) async {
  //   AgoraUser _tempUser = state.activeUsers.singleWhere((element) => element.uid == uid);
  //   Set<AgoraUser> _tempSet = state.activeUsers;
  //   _tempSet.remove(_tempUser);
  //   _tempSet.add(_tempUser.copyWith(muted: muted));
  //   state = state.copyWith(activeUsers: _tempSet);
  // }

  // Future updateUserVideo({required int uid , required bool videoDisabled}) async {
  //   AgoraUser _tempUser = state.activeUsers.singleWhere((element) => element.uid == uid);
  //   Set<AgoraUser> _tempSet = state.activeUsers;
  //   _tempSet.remove(_tempUser);
  //   _tempSet.add(_tempUser.copyWith(videoDisabled: videoDisabled));
  //   state = state.copyWith(activeUsers: _tempSet);
  // }

  Future toggleUserAudio({required int index, required bool muted}) async {
    if(muted && state.activeUsers.elementAt(index).didUserMuted == false){
      AgoraUser _tempUser = state.activeUsers.elementAt(index);
      Set<AgoraUser> _tempSet = state.activeUsers;
      _tempSet.remove(_tempUser);
      _tempSet.add(_tempUser.copyWith(muted: false));
      state = state.copyWith(activeUsers: _tempSet);

      state.channel?.sendMessage2(RtmMessage.fromText("unmute ${state.activeUsers.elementAt(index).uid}"));
    }
    if(!muted && state.activeUsers.elementAt(index).didUserMuted == false){
      AgoraUser _tempUser = state.activeUsers.elementAt(index);
      Set<AgoraUser> _tempSet = state.activeUsers;
      _tempSet.remove(_tempUser);
      _tempSet.add(_tempUser.copyWith(muted: true));
      state = state.copyWith(activeUsers: _tempSet);

      state.channel?.sendMessage2(RtmMessage.fromText("mute ${state.activeUsers.elementAt(index).uid}"));
    }
  }

  Future toggleUserVideo({required int index, required bool enable}) async {
    if(enable && state.activeUsers.elementAt(index).didUserDisabled == false){
      AgoraUser _tempUser = state.activeUsers.elementAt(index);
      Set<AgoraUser> _tempSet = state.activeUsers;
      _tempSet.remove(_tempUser);
      _tempSet.add(_tempUser.copyWith(videoDisabled: true));
      state = state.copyWith(activeUsers: _tempSet);
      state.channel?.sendMessage2(RtmMessage.fromText("disable ${state.activeUsers.elementAt(index).uid}"));
    }
    if(!enable && state.activeUsers.elementAt(index).didUserDisabled == false){
      AgoraUser _tempUser = state.activeUsers.elementAt(index);
      Set<AgoraUser> _tempSet = state.activeUsers;
      _tempSet.remove(_tempUser);
      _tempSet.add(_tempUser.copyWith(videoDisabled: false));
      state = state.copyWith(activeUsers: _tempSet);
      state.channel?.sendMessage2(RtmMessage.fromText("enable ${state.activeUsers.elementAt(index).uid}"));
    }
  }
}