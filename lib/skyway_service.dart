import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:skyway_sample/config.dart';

// ネイティブの呼び出し
const MethodChannel _channel = MethodChannel("skyway_service");
final AutoDisposeChangeNotifierProvider<SkywayService> skywayServiceProvider =
    ChangeNotifierProvider.autoDispose((ref) => SkywayService());

class SkywayService extends ChangeNotifier {
  // iOSとAndroidのカメラ映像の表示、idでローカルストリームとリモートストリームを分ける
  Widget platformView({@required int? viewId}) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: 'skyway_service/video_view',
        onPlatformViewCreated: (id) {
          print('UiKitView created: id = $id');
        },
        creationParams: {
          'id': viewId,
        },
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: 'skyway_service/video_view',
        onPlatformViewCreated: (id) {
          print('AndroidView created: id = $id');
        },
        creationParams: {
          'id': viewId,
        },
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else {
      return const Center(
        child: Text(
          'No supported by the plugin',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      );
    }
  }

  // 設定されたAPIキーとドメインでSkywayサーバーに接続
  Future<SkywayServicePeer> connect(String peerId) async {
    const String apiKey = API_KEY;
    const String domain = 'localhost';
    await _channel.invokeMethod('connect', {
      'apiKey': apiKey,
      'domain': domain,
      'peerId': peerId,
    });
    return SkywayServicePeer(peerId: peerId)..initialize();
  }
}

typedef ReceiveCallCallback = void Function(String remotePeerId);

class SkywayServicePeer {
  final String? peerId;
  SkywayServicePeer({this.peerId});

  // メイン画面のコールバック
  ReceiveCallCallback? onReceiveCall;
  ReceiveCallCallback? onClosedCall;

  // ネイティブからの通知購読
  StreamSubscription<dynamic>? _eventSubscription;

  void initialize() {
    _eventSubscription = EventChannel('skyway_service/$peerId')
        .receiveBroadcastStream()
        .listen(_eventListener, onError: _errorListener);
  }

  Future<void> dispose() async {
    await _eventSubscription?.cancel();
  }

  // 電話を受けたときと切られたときの通知
  void _eventListener(dynamic event) {
    final Map<dynamic, dynamic> map = event;
    switch (map['event']) {
      case 'onCall':
        print('onCall: $map');
        if (onReceiveCall != null) {
          onReceiveCall!(map['from']);
        }
        break;
      case 'onClose':
        print('onClose: $map');
        if (onClosedCall != null) {
          onClosedCall!(map['from']);
        }
        break;
    }
  }

  void _errorListener(Object obj) {
    print('onError: $obj');
  }

  // 切断
  Future<void> destroy() async {
    _eventSubscription?.cancel();
    await _channel.invokeMethod('destroy', {
      'peerId': peerId,
    });
  }

  // 電話をかける
  Future<void> call(String targetPeerId) async {
    await _channel.invokeMethod('call', {
      'peerId': peerId,
      'targetPeerId': targetPeerId,
    });
  }

  // サーバーに接続されているPeerIDを取得
  Future<List<String>> listAllPeers() async {
    final List<dynamic> peers = await _channel.invokeMethod('listAllPeers', {
      'peerId': peerId,
    });
    return peers.cast<String>();
  }

  // マイクの切り替え
  Future<void> enableAudio() async {
    await _channel.invokeMethod('enableAudio', {
      'peerId': peerId,
    });
  }

  // ビデオの切り替え
  Future<void> enableVideo() async {
    await _channel.invokeMethod('enableVideo', {
      'peerId': peerId,
    });
  }

  // カメラの切り替え
  Future<void> switchCamera() async {
    await _channel.invokeMethod('switchCamera', {
      'peerId': peerId,
    });
  }
}
