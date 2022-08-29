import Flutter
import UIKit
import SkyWay

class SkywayService: NSObject, FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "skyway_service", binaryMessenger: registrar.messenger())
        let instance = SkywayService(messenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.register(instance, withId: "skyway_service/video_view")
    }
    
    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }
    
    private let messenger: FlutterBinaryMessenger
    
    private var peers = [String: SkywayPeer]()
    private let localView = UIView()
    private let remoteView = UIView()
    private let errorView = UIView()
    
    public func handle(_ methodCall: FlutterMethodCall, result: @escaping FlutterResult) {
        enum Method: String {
            case connect
            case destroy
            case call
            case listAllPeers
            case enableAudio
            case enableVideo
            case switchCamera
        }

        guard let method = Method.init(rawValue: methodCall.method) else {
            result(FlutterMethodNotImplemented)
            return
        }
        switch method {
        case .connect:      self.connect(methodCall, result: result)
        case .destroy:      self.destroy(methodCall, result: result)
        case .call:         self.call(methodCall, result: result)
        case .listAllPeers: self.listAllPeers(methodCall, result: result)
        case .enableAudio:  self.enableAudio(methodCall, result: result)
        case .enableVideo:  self.enableVideo(methodCall, result: result)
        case .switchCamera: self.switchCamera(methodCall, result: result)
        }
    }

    // Skywayサーバーへ接続
    private func connect(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
       guard let args = call.arguments as? [String: Any],
           let apiKey = args["apiKey"] as? String,
           let domain = args["domain"] as? String,
           let peerId = args["peerId"] as? String else {
               result(FlutterError(code: "InvalidArguments",
                                   message: "`apiKey` and `domain` must not be null.",
                                   details: nil))
               return
       }
       let option = SKWPeerOption()
       option.key = apiKey
       option.domain = domain
       option.debug = SKWDebugLevelEnum.DEBUG_LEVEL_ALL_LOGS
       
       guard let skwPeer = SKWPeer(id: peerId, options: option) else {
           result(FlutterError(code: "Unknown", message: "Peer creation failed.", details: nil))
           return
       }
       let peer = SkywayPeer(peer: skwPeer)
       peers[peerId] = peer

       peer.connect { [weak self] (error) in
           if let error = error {
               self?.peers.removeValue(forKey: peerId)
               result(error)
               return
           }
           peer.eventChannel = self?.createEventChannel(peerId: peerId)
           result(peerId)
       }
    }

    // Flutterへ通知するチャンネルの生成
    private func createEventChannel(peerId: String) -> FlutterEventChannel? {
        return FlutterEventChannel(name: "skyway_service/\(peerId)", binaryMessenger: self.messenger)
    }

    // 切断
    private func destroy(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
       guard let args = call.arguments as? [String: Any],
           let peerId = args["peerId"] as? String else {
               result(nil)
               return
       }
       if let peer = peers[peerId] {
           peer.destroy()
       }
       peers.removeValue(forKey: peerId)
       result(nil)
    }

    // 電話をかける
    private func call(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
       guard let args = call.arguments as? [String: Any],
           let peerId = args["peerId"] as? String,
           let targetPeerId = args["targetPeerId"] as? String,
           let peer = peers[peerId] else {
               result(FlutterError(code: "InvalidArguments", message: nil, details: nil))
               return
       }
       peer.call(to: targetPeerId) { (error) in
           result(error)
       }
    }

    // サーバーに接続されているPeerIDを取得
    private func listAllPeers(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
       guard let args = call.arguments as? [String: Any],
           let peerId = args["peerId"] as? String,
           let peer = peers[peerId] else {
               result([String]())
               return
       }
       peer.listAllPeers { allPeers in
           result(allPeers)
       }
    }

    // マイクの切り替え
    private func enableAudio(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
       guard let args = call.arguments as? [String: Any],
           let peerId = args["peerId"] as? String,
           let peer = peers[peerId] else {
               result(FlutterError(code: "InvalidArguments", message: nil, details: nil))
               return
       }
       peer.enableAudio() { (error) in
           result(error)
       }
    }

    // ビデオの切り替え
    private func enableVideo(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
       guard let args = call.arguments as? [String: Any],
           let peerId = args["peerId"] as? String,
           let peer = peers[peerId] else {
               result(FlutterError(code: "InvalidArguments", message: nil, details: nil))
               return
       }
       peer.enableVideo() { (error) in
           result(error)
       }
    }

    // カメラの切り替え
    private func switchCamera(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
       guard let args = call.arguments as? [String: Any],
           let peerId = args["peerId"] as? String,
           let peer = peers[peerId] else {
               result(FlutterError(code: "InvalidArguments", message: nil, details: nil))
               return
       }
       peer.switchCamera() { (error) in
           result(error)
       }
    }
}

// PlatformViewの生成
extension SkywayService: FlutterPlatformViewFactory {
    // UIKitViewのcreationParamsの値をcreate関数のargsに渡す
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
    // switchViewでidによって自分の画像か相手の画像か判別する
    public func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        guard let map = args as? Dictionary<String, Any?> else {
            return SkywayServicePlatformView(errorView)
        }
        let view = switchView(frame: frame, args: map as Dictionary<String, Any>)
        return SkywayServicePlatformView(view)
    }
    private func switchView(frame: CGRect, args: Dictionary<String, Any>) -> UIView {
        let id = args["id"] as! Int
        switch id {
        case 0:
            localView.frame = frame
            localView.backgroundColor = .black
            if let view = peers.first?.value.localStreamView {
                view.frame = localView.bounds
                view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                localView.addSubview(view)
            }
            return localView
        case 1:
            remoteView.frame = frame
            remoteView.backgroundColor = .black
            if let view = peers.first?.value.remoteStreamView {
                view.frame = remoteView.bounds
                view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                remoteView.addSubview(view)
            }
            return remoteView
        default:
            errorView.backgroundColor = .red
            return errorView
        }
    }
}

class SkywayServicePlatformView: NSObject, FlutterPlatformView {
    let platformView: UIView
    init(_ platformView: UIView) {
        self.platformView = platformView
        super.init()
    }
    func view() -> UIView {
        return platformView
    }
}
