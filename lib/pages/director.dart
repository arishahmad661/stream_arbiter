import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_streaming/controllers/director_controller.dart';
import 'package:live_streaming/models/director.dart';

class Director extends ConsumerStatefulWidget {
  final String channelName;
  final int uid;
  const Director({super.key, required this.channelName, required this.uid,});

  @override
  ConsumerState<Director> createState() => _DirectorState();
}

class _DirectorState extends ConsumerState<Director> {

  @override
  void initState() {
    // TODO: implement initState'
    super.initState();
    ref.read(directorController.notifier).joinCall(channelName: widget.channelName, uid: widget.uid);
  }
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Consumer(
      builder: (context, ref, child) {
        DirectorController directorNotifier = ref.watch(directorController.notifier);
        DirectorModel directorData = ref.watch(directorController);
        return Scaffold(
          body:Padding(
            padding: const EdgeInsets.all(8.0),
            child: CustomScrollView(
              slivers: [
                SliverList(delegate: SliverChildListDelegate(
                  [
                    const SafeArea(child: Text("Director"))
                  ]
                )),
                if(directorData.activeUsers.isEmpty)
                  SliverList(delegate: SliverChildListDelegate([
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: const Text("Empty Stage"),
                      ),
                    )
                  ])),
                  SliverGrid(

                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: MediaQuery.of(context).size.width/2, crossAxisSpacing: 20, mainAxisSpacing: 20),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return Row(
                        children: [
                          Expanded(child: StageUser(directorData: directorData, directorNotifier: directorNotifier, index: index))
                        ],
                      );
                    },
                    childCount: directorData.activeUsers.length)
                ),
                  SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Divider(
                          thickness: 3,
                          indent: 80,
                          endIndent: 80,
                        ),
                      ),
                    ],
                  ),
                ),
                if(directorData.lobbyUsers.isEmpty)
                  SliverList(delegate: SliverChildListDelegate([
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: const Text("Empty Lobby"),
                      ),
                    )
                  ])),
                  SliverGrid(gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: MediaQuery.of(context).size.width/2, crossAxisSpacing: 20, mainAxisSpacing: 20),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return Row(
                        children: [
                          Expanded(child: LobbyUser(directorData: directorData, directorNotifier: directorNotifier, index: index))
                        ],
                      );
                    },childCount: directorData.lobbyUsers.length)
                ),
                  SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Divider(
                          thickness: 3,
                          indent: 80,
                          endIndent: 80,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        );
      }
    );
  }
}


class StageUser extends StatefulWidget {
  const StageUser({
    Key? key,
    required this.directorData,
    required this.directorNotifier,
    required this.index,
  }) : super(key: key);

  final DirectorModel directorData;
  final DirectorController directorNotifier;
  final int index;

  @override
  State<StageUser> createState() => _StageUserState();
}

class _StageUserState extends State<StageUser> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: widget.directorData.activeUsers.elementAt(widget.index).videoDisabled
                ? Stack(children: [
              Container(
                color: Colors.black,
              ),
              const Align(
                alignment: Alignment.center,
                child: Text(
                  "Video Off",
                  style: TextStyle(color: Colors.white),
                ),
              )
            ])
                : Stack(children: [
              AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: createAgoraRtcEngine(),
                  canvas: VideoCanvas(uid: widget.directorData.activeUsers.elementAt(widget.index).uid),
                  connection: RtcConnection(channelId: widget.directorData.channel?.channelId),
                ),
              ),
              // RtcRemoteView.SurfaceView(uid: directorData.activeUsers.elementAt(index).uid),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(10)),
                      color: widget.directorData.activeUsers.elementAt(widget.index).backgroundColor!.withOpacity(1)),
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    widget.directorData.activeUsers.elementAt(widget.index).name ?? "name error",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ]),
          ),
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.black54),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    if (widget.directorData.activeUsers.elementAt(widget.index).muted) {
                      widget.directorNotifier.toggleUserAudio(index: widget.index, muted: true);
                    } else {
                      widget.directorNotifier.toggleUserAudio(index: widget.index, muted: false);
                    }
                  },
                  icon: const Icon(Icons.mic_off),
                  color: (widget.directorData.activeUsers.elementAt(widget.index).muted || widget.directorData.activeUsers.elementAt(widget.index).didUserMuted) ? Colors.red : Colors.white,
                ),
                IconButton(
                  onPressed: () {
                    if (widget.directorData.activeUsers.elementAt(widget.index).videoDisabled) {
                      widget.directorNotifier.toggleUserVideo(index: widget.index, enable: false);
                    } else {
                      widget.directorNotifier.toggleUserVideo(index: widget.index, enable: true);
                    }
                  },
                  icon: const Icon(Icons.videocam_off),
                  color: widget.directorData.activeUsers.elementAt(widget.index).videoDisabled ||  widget.directorData.activeUsers.elementAt(widget.index).didUserDisabled ? Colors.red : Colors.white,
                ),
                IconButton(
                  onPressed: () {
                    widget.directorNotifier.demoteToLobbyUser(uid: widget.directorData.activeUsers.elementAt(widget.index).uid);
                  },
                  icon: const Icon(Icons.arrow_downward),
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LobbyUser extends StatelessWidget {
  const LobbyUser({
    Key? key,
    required this.directorData,
    required this.directorNotifier,
    required this.index,
  }) : super(key: key);

  final DirectorModel directorData;
  final DirectorController directorNotifier;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: directorData.lobbyUsers.elementAt(index).videoDisabled
                ? Stack(children: [
              Container(
                color: (directorData.lobbyUsers.elementAt(index).backgroundColor != null)
                    ? directorData.lobbyUsers.elementAt(index).backgroundColor!.withOpacity(1)
                    : Colors.black,
              ),
              Align(
                alignment: Alignment.center,
                child: Text(
                  directorData.lobbyUsers.elementAt(index).name ?? "error name",
                  style: const TextStyle(color: Colors.white),
                ),
              )
            ])
                :
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: directorData.engine ?? createAgoraRtcEngine(),
                canvas: VideoCanvas(uid: directorData.lobbyUsers.elementAt(index).uid),
                connection: RtcConnection(channelId: directorData.channel?.channelId),
              ),
            )
            // RtcRemoteView.SurfaceView(uid: directorData.lobbyUsers.elementAt(index).uid,),
          ),
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.black54),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    directorNotifier.promoteToActiveUser(uid: directorData.lobbyUsers.elementAt(index).uid);
                  },
                  icon: const Icon(Icons.arrow_upward),
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

