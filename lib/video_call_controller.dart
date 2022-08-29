import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:skyway_sample/skyway_service.dart';

import 'config.dart';

final AutoDisposeChangeNotifierProvider<VideoCallController>
    videoCallController =
    ChangeNotifierProvider.autoDispose((ref) => VideoCallController(ref.read));

class VideoCallController extends ChangeNotifier {
  VideoCallController(this.read) {
    connect();
  }

  Reader read;
  String status = '';
  bool isWaiting = true;
  bool isConnecting = false;
  bool isCalling = false;
  bool isDisconnected = false;
  bool isEnabledAudio = true;
  bool isEnabledVideo = true;
  bool isCameraFront = true;
  SkywayServicePeer? peer;
  List<String>? peers;
  String peerId = '';
  String targetPeerId = '';

  bool get isConnected {
    return peer != null;
  }

  SkywayService get skywayService => read(skywayServiceProvider);

  // サーバーに接続
  Future<void> connect() async {
    if (Platform.isAndroid) {
      peerId = ANDROID_ID;
    } else {
      peerId = IOS_ID;
    }
    if (isConnecting) {
      return;
    }

    isConnecting = true;
    status = 'Connecting...';
    print(status);

    SkywayServicePeer? peer;

    await checkPermission();
    try {
      peer = await skywayService.connect(peerId);
      peer.onReceiveCall = onReceiveCall;
      peer.onClosedCall = onClosedCall;
      status = 'Connected!';
    } on PlatformException catch (e) {
      print(e);
      status = 'Failed to connect.';
      print(status);
    }

    isConnecting = false;
    print(status);
    this.peer = peer;
    print(this.peer?.peerId);

    notifyListeners();
  }

  // サーバーと相手を切断
  Future<void> disconnect() async {
    if (peer != null) {
      await peer?.destroy();
    }
    status = 'Disconnected.';
    print(status);
    peer = null;

    notifyListeners();
  }

  // 電話をかける
  Future<void> call() async {
    if (!isConnected) {
      return;
    }
    if (Platform.isAndroid) {
      targetPeerId = IOS_ID;
    } else {
      targetPeerId = ANDROID_ID;
    }
    if (isConnecting) {
      return;
    }

    try {
      peer?.call(targetPeerId);
    } on PlatformException catch (e) {
      print(e);
    }
    isCalling = true;
    print('call to $targetPeerId');

    notifyListeners();
  }

  // 電話を受ける
  Future<void> onReceiveCall(String remotePeerId) async {
    isCalling = true;
    print('receive call from $remotePeerId');

    notifyListeners();
  }

  // 電話を切られたとき
  Future<void> onClosedCall(String remotePeerId) async {
    isDisconnected = true;
    disconnect();
    print('Closed $remotePeerId');

    notifyListeners();
  }

  // カメラ、マイクの権限付与
  Future<void> checkPermission() async {
    final PermissionStatus cameraStatus = await Permission.camera.status;
    final PermissionStatus microphoneStatus =
        await Permission.microphone.status;
    print(await Permission.camera.status.isDenied);
    print(await Permission.microphone.status.isDenied);

    if ((cameraStatus.isDenied && microphoneStatus.isDenied) ||
        (cameraStatus.isPermanentlyDenied &&
            microphoneStatus.isPermanentlyDenied) ||
        (cameraStatus.isRestricted && microphoneStatus.isRestricted) ||
        (cameraStatus.isGranted && microphoneStatus.isGranted)) {
      await Permission.camera.request();
      await Permission.microphone.request();
    } else if (cameraStatus.isGranted && microphoneStatus.isGranted) {
      return;
    } else {
      // openAppSettings();
    }
  }

  // サーバーに接続されているPeerIDを取得
  Future<void> fetchAllPeers(String targetPeerId) async {
    if (!isConnected) {
      return;
    }
    late List<String> peers;
    try {
      peers = await peer!.listAllPeers();
      peers = peers.where((peerId) => peerId != peer?.peerId).toList();
    } on PlatformException catch (e) {
      print(e);
    }
    this.peers = peers;
    final bool checkWaiting = peers.contains(targetPeerId);
    if (checkWaiting) {
      isWaiting = false;
    }

    notifyListeners();
  }

  // マイクの切り替え
  Future<void> enableAudio() async {
    isEnabledAudio = !isEnabledAudio;
    peer?.enableAudio();
    notifyListeners();
  }

  // ビデオの切り替え
  Future<void> enableVideo() async {
    isEnabledVideo = !isEnabledVideo;
    peer?.enableVideo();
    notifyListeners();
  }

  // カメラの切り替え
  Future<void> switchCamera() async {
    isCameraFront = !isCameraFront;
    peer?.switchCamera();
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
