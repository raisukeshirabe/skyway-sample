import Flutter
import UIKit
import SkyWay
import AVFoundation

// Skywayとの接続
final class SkywayPeer: NSObject {

    private let peer: SKWPeer
    init(peer: SKWPeer) {
        self.peer = peer
        super.init()
    }

    var eventChannel: FlutterEventChannel? {
        didSet {
            oldValue?.setStreamHandler(nil)
            eventChannel?.setStreamHandler(self)
        }
    }
    var eventSink: FlutterEventSink?

    private var mediaConnection: SKWMediaConnection?
    private var localStream: SKWMediaStream?
    private var remoteStream: SKWMediaStream?

    let localStreamView = SKWVideo()
    let remoteStreamView = SKWVideo()

    var identity: String? {
        return peer.identity
    }

    // 接続
    func connect(completion: @escaping (FlutterError?) -> Void) {
        peer.on(.PEER_EVENT_ERROR) { (error) in
            if let error = error as? SKWPeerError {
                completion(FlutterError(code: "SKWPeerError", message: error.message, details: nil))
            }
        }
        peer.on(.PEER_EVENT_OPEN) { (_) in
                completion(nil)
        }
        peer.on(.PEER_EVENT_CALL) { [weak self] (connection) in
            if let connection = connection as? SKWMediaConnection {
                self?.onCall(mediaConnection: connection)
            }
        }
    }

    // 電話をかける
    func call(to targetPeerId: String, completion: @escaping (FlutterError?) -> Void) {
        guard mediaConnection == nil else {
            completion(FlutterError(code: "InvalidState", message: nil, details: nil))
            return
        }
        createLocalStream()
        let option = SKWCallOption()
        guard let mediaConnection = peer.call(withId: targetPeerId, stream: self.localStream, options: option) else {
            completion(FlutterError(code: "PeerError", message: "failed to call :\(targetPeerId)", details: nil))
            return
        }
        setUpMediaConnectionCallbacks(mediaConnection: mediaConnection)
    }

    // 電話を受ける
    private func onCall(mediaConnection: SKWMediaConnection) {
        guard self.mediaConnection == nil,
            let from = mediaConnection.peer else {
            mediaConnection.close()
            return
        }
        self.mediaConnection = mediaConnection
        createLocalStream()
        setUpMediaConnectionCallbacks(mediaConnection: mediaConnection)
        mediaConnection.answer(self.localStream)
        eventSink?(["event": "onCall", "from": from])
    }

    // サーバーに接続されているPeerIDを取得
    func listAllPeers(completion: @escaping ([String]) -> Void) {
            peer.listAllPeers { allPeers in
                completion((allPeers as? [String]) ?? [String]())
            }
        }

    // マイクの切り替え
    func enableAudio(completion: @escaping (FlutterError?) -> Void) {
        if localStream == nil {
            return
        }
        guard let isEnabledAudio = localStream?.getEnableAudioTrack(0) else {
            completion(FlutterError(code: "AudioError", message: nil, details: nil))
            return
        }
        if isEnabledAudio {
            localStream?.setEnableAudioTrack(0, enable: false)
        } else {
            localStream?.setEnableAudioTrack(0, enable: true)
        }
    }

    // ビデオの切り替え
    func enableVideo(completion: @escaping (FlutterError?) -> Void) {
        if localStream == nil {
            return
        }
        guard let isEnabledVideo = localStream?.getEnableVideoTrack(0) else {
            completion(FlutterError(code: "VideoError", message: nil, details: nil))
            return
        }
        if isEnabledVideo {
            localStream?.setEnableVideoTrack(0, enable: false)
        } else {
            localStream?.setEnableVideoTrack(0, enable: true)
        }
    }
    
    // カメラの切り替え
    func switchCamera(completion: @escaping (FlutterError?) -> Void) {
        if localStream == nil {
            return
        }
        guard let cameraPosition = localStream?.getCameraPosition() else {
            completion(FlutterError(code: "CameraError", message: nil, details: nil))
            return
        }
        if cameraPosition == SKWCameraPositionEnum.CAMERA_POSITION_FRONT {
            localStream?.setCameraPosition(SKWCameraPositionEnum.CAMERA_POSITION_BACK)
        } else {
            localStream?.setCameraPosition(SKWCameraPositionEnum.CAMERA_POSITION_FRONT)
        }
    }
    
    // ローカルストリームの生成
    private func createLocalStream() {
        SKWNavigator.initialize(peer)
        let constraints = SKWMediaConstraints()
        constraints.cameraPosition = SKWCameraPositionEnum.CAMERA_POSITION_FRONT
        guard let localStream = SKWNavigator.getUserMedia(constraints) else { return }
        localStreamView.scaling = SKWVideoScalingEnum.VIDEO_SCALING_ASPECT_FILL
        localStream.addVideoRenderer(localStreamView, track: 0)
        self.localStream = localStream
    }
    
    // リモートストリームの取得
    private func setUpRemoteStream(_ remoteStream: SKWMediaStream) {
        self.remoteAudioSpeaker()
        remoteStreamView.scaling = SKWVideoScalingEnum.VIDEO_SCALING_ASPECT_FILL
        remoteStream.addVideoRenderer(remoteStreamView, track: 0)
        self.remoteStream = remoteStream
    }

    // リモートオーディオの取得
    func remoteAudioSpeaker() {
        self.remoteStream?.setEnableAudioTrack(0, enable: true)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
        } catch let error as NSError {
            print("audioSession error: \(error.localizedDescription)")
        }
    }

    // メディアコネクションのコールバック、STREAMで映像を流してCLOSEで相手から切断されたら発火する
    private func setUpMediaConnectionCallbacks(mediaConnection: SKWMediaConnection) {
        mediaConnection.on(.MEDIACONNECTION_EVENT_STREAM) { [weak self] (remoteStream) in
            if let remoteStream = remoteStream as? SKWMediaStream {
                self?.setUpRemoteStream(remoteStream)
            }
        }
        mediaConnection.on(.MEDIACONNECTION_EVENT_CLOSE) { [weak self] (remoteStream) in
            self?.onClose(mediaConnection: mediaConnection)
        }
        mediaConnection.on(SKWMediaConnectionEventEnum.MEDIACONNECTION_EVENT_ERROR) { (error) in
            if let error = error as? SKWPeerError {
                print("\(error)")
            }
        }
    }
    
    // 相手から切断されたことをFlutterに通知
    private func onClose(mediaConnection: SKWMediaConnection) {
        guard let from = mediaConnection.peer else {
            mediaConnection.close()
            return
        }
        self.mediaConnection = mediaConnection
        eventSink?(["event": "onClose", "from": from])
    }

    // 切断
    func destroy() {
        closeRemoteStream()
        closeLocalStream()
        if nil != mediaConnection {
            if ((mediaConnection?.isOpen) != nil) {
                mediaConnection?.close()
            }
            unsetMediaCallbacks()
        }
        SKWNavigator.terminate()
        
        if !peer.isDisconnected {
            peer.disconnect()
        }
        if !peer.isDestroyed {
            peer.destroy()
        }
        unsetPeerCallback(peer: peer)
    }
    
    // ピアコネクションの開放
    private func unsetPeerCallback(peer: SKWPeer) {
        peer.on(SKWPeerEventEnum.PEER_EVENT_OPEN, callback: nil)
        peer.on(SKWPeerEventEnum.PEER_EVENT_CONNECTION, callback: nil)
        peer.on(SKWPeerEventEnum.PEER_EVENT_CALL, callback: nil)
        peer.on(SKWPeerEventEnum.PEER_EVENT_CLOSE, callback: nil)
        peer.on(SKWPeerEventEnum.PEER_EVENT_DISCONNECTED, callback: nil)
        peer.on(SKWPeerEventEnum.PEER_EVENT_ERROR, callback: nil)
    }
    
    // メディアコネクションの開放
    private func unsetMediaCallbacks() {
        if nil == mediaConnection {
            return
        }
        mediaConnection?.on(SKWMediaConnectionEventEnum.MEDIACONNECTION_EVENT_STREAM, callback: nil)
        mediaConnection?.on(SKWMediaConnectionEventEnum.MEDIACONNECTION_EVENT_CLOSE, callback: nil)
        mediaConnection?.on(SKWMediaConnectionEventEnum.MEDIACONNECTION_EVENT_ERROR, callback: nil)
        mediaConnection = nil
    }
    // ローカルストリームの開放
    private func closeLocalStream() {
        if nil == localStream {
            return;
        }
        localStream?.removeVideoRenderer(localStreamView, track: 0)
        localStream?.close()
        localStream = nil
    }
    // リモートストリームの開放
    private func closeRemoteStream() {
        if nil == remoteStream {
            return;
        }
        remoteStream?.removeVideoRenderer(remoteStreamView, track: 0)
        remoteStream?.close()
        remoteStream = nil
    }
}

extension SkywayPeer: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
