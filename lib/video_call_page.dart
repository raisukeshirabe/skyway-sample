import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:skyway_sample/skyway_service.dart';
import 'package:skyway_sample/video_call_controller.dart';

class VideoCallPage extends HookWidget {
  Widget gap() {
    return const SizedBox(width: 24);
  }

  @override
  Widget build(BuildContext context) {
    final controller = useProvider(videoCallController);
    final skywayService = useProvider(skywayServiceProvider);
    return WillPopScope(
      onWillPop: _willPopCallback,
      child: Scaffold(
        body: Stack(
          children: <Widget>[
            controller.isConnecting
                ? const Center(
                    child: SizedBox(
                      child: CircularProgressIndicator(),
                      width: 30,
                      height: 30,
                    ),
                  )
                // remoteViewの表示
                : SizedBox(
                    child: skywayService.platformView(
                      viewId: 1,
                    ),
                    width: double.infinity,
                    height: double.infinity,
                  ),
            // localViewの表示
            Positioned(
              right: 24,
              bottom: 120,
              child: Align(
                alignment: Alignment.bottomRight,
                child: controller.isCalling
                    ? Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            width: 3,
                            color: Colors.white,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: skywayService.platformView(
                          viewId: 0,
                        ),
                        width: 96,
                        height: 136,
                      )
                    : Container(),
              ),
            ),
            Container(
              padding: const EdgeInsets.only(top: 40, bottom: 60),
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                      icon: controller.isEnabledAudio
                          ? const Icon(Icons.mic_outlined)
                          : const Icon(Icons.mic_off),
                      iconSize: 42,
                      color: Colors.white,
                      onPressed: () {
                        controller.enableAudio();
                      }),
                  gap(),
                  controller.isCalling
                      ? IconButton(
                          icon: const Icon(Icons.call_end),
                          iconSize: 56,
                          color: Colors.red,
                          onPressed: () {
                            controller.disconnect();
                            Navigator.pop(context);
                          },
                        )
                      : IconButton(
                          icon: const Icon(Icons.call),
                          iconSize: 56,
                          color: Colors.green,
                          onPressed: () {
                            controller.call();
                          },
                        ),
                  gap(),
                  IconButton(
                    icon: controller.isEnabledVideo
                        ? const Icon(Icons.videocam_rounded)
                        : const Icon(Icons.videocam_off),
                    iconSize: 42,
                    color: Colors.white,
                    onPressed: () {
                      controller.enableVideo();
                    },
                  ),
                ],
              ),
            ),
            Positioned(
              top: 66,
              right: 24,
              child: Align(
                alignment: Alignment.topRight,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(CupertinoIcons.switch_camera),
                      iconSize: 42,
                      color: Colors.white,
                      onPressed: () {
                        controller.switchCamera();
                      },
                    ),
                  ],
                ),
              ),
            ),
            // 切断された時Dialogを表示
            closeDialog(context, controller)
          ],
        ),
      ),
    );
  }

  // 相手が接続状態の時、CALLボタンを表示
  Widget callDialog(BuildContext context, VideoCallController controller) {
    // サーバーに接続されているpeerIDを取得
    return controller.targetPeerId != null &&
            !controller.isCalling // 相手がサーバーに接続していて待機中だったら
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    primary: Colors.white.withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.only(
                        top: 16, left: 20, right: 20, bottom: 16),
                  ),
                  child: const Text(
                    'カメラをオンにして参加',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  onPressed: () async {
                    // await controller.fetchAllPeers(controller.targetPeerId!);
                    !controller.isWaiting
                        ? await controller.call()
                        : alertDialog(context, controller);
                  },
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    primary: Colors.white.withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.only(
                        top: 16, left: 20, right: 20, bottom: 16),
                  ),
                  child: const Text(
                    'カメラをオフにして参加',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  onPressed: () async {
                    // await controller.fetchAllPeers(targetPeerId!);
                    !controller.isWaiting
                        ? await controller.call()
                        : alertDialog(context, controller);
                    await controller.enableVideo();
                  },
                ),
              ],
            ),
          )
        : Center(
            child: controller.isCalling
                ? Container()
                : Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: const CircleAvatar(
                          radius: 50, child: const Icon(Icons.person)),
                    ),
                  ),
          );
  }

  Future<void> alertDialog(
      BuildContext context, VideoCallController controller) {
    int count = 0;
    return showDialog(
        context: context,
        builder: (context) {
          return CupertinoAlertDialog(
            title: const Text('接続できませんでした'),
            actions: <Widget>[
              CupertinoDialogAction(
                child: const Text('閉じる'),
                onPressed: () {
                  controller.disconnect();
                  Navigator.of(context).popUntil((_) => count++ >= 2);
                },
              ),
            ],
          );
        });
  }

  // 通話終了のDialog、OKボタンでSkywayサーバーから切断する
  Widget closeDialog(BuildContext context, VideoCallController controller) {
    return controller.isDisconnected
        ? Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black.withOpacity(0.8),
            child: CupertinoAlertDialog(
              title: const Text('通話終了'),
              actions: <Widget>[
                CupertinoDialogAction(
                  child: const Text('閉じる'),
                  onPressed: () {
                    controller.disconnect();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          )
        : Container();
  }

  // スワイプで画面に戻らないようにする
  Future<bool> _willPopCallback() async {
    return true;
  }
}
