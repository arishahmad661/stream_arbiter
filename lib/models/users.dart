import 'package:flutter/material.dart';

class AgoraUser {
  int uid;
  bool muted;
  bool videoDisabled;
  bool didUserMuted;
  bool didUserDisabled;
  String? name;
  Color? backgroundColor;

  AgoraUser({
    required this.uid,
    this.muted = false,
    this.videoDisabled = false,
    this.didUserMuted = false,
    this.didUserDisabled = false,
    this.name,
    this.backgroundColor,
  });

  AgoraUser copyWith({
    int? uid,
    bool? muted,
    bool? videoDisabled,
    bool? didUserMuted,
    bool? didUserDisabled,
    String? name,
    Color? backgroundColor,
  }) {
    return AgoraUser(
      uid: uid ?? this.uid,
      muted: muted ?? this.muted,
      videoDisabled: videoDisabled ?? this.videoDisabled,
      didUserDisabled: didUserDisabled ?? this.didUserDisabled,
      didUserMuted: didUserMuted ?? this.didUserMuted,
      name: name ?? this.name,
      backgroundColor: backgroundColor ?? this.backgroundColor,

    );
  }
}