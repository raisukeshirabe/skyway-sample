package com.example.skyway_sample;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Context;
import android.graphics.Color;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import org.json.JSONArray;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.skyway.Peer.Browser.Canvas;
import io.skyway.Peer.Browser.MediaConstraints;
import io.skyway.Peer.Browser.MediaStream;
import io.skyway.Peer.Browser.Navigator;
import io.skyway.Peer.CallOption;
import io.skyway.Peer.MediaConnection;
import io.skyway.Peer.Peer;
import io.skyway.Peer.PeerError;

public class SkywayPeer {

    private static final boolean DEBUG = true;
    private static final String TAG = SkywayPeer.class.getSimpleName();

    public interface OnListAllPeersCallback {
        void onListAllPeers(@NonNull final List<String> list);
    }

    @NonNull
    private final Object mSync = new Object();
    @NonNull
    private final Activity _activity;
    @NonNull
    private final String _peerId;
    @NonNull
    private final Peer _peer;
    @Nullable
    private EventChannel.EventSink _eventSink;
    private MediaStream _localStream;
    private MediaStream _remoteStream;
    private MediaConnection _mediaConnection;

    public static Canvas localStreamView;
    public static Canvas remoteStreamView;

    public SkywayPeer(@NonNull final Activity activity,
                     @NonNull final String peerId,
                     @NonNull final Peer peer,
                     @NonNull final BinaryMessenger binaryMessenger) {
        if (DEBUG) Log.v(TAG, "Instance of SkywayPeer");
        _activity = activity;
        _peerId = peerId;
        _peer = peer;
        localStreamView = new Canvas(activity.getApplicationContext());
        remoteStreamView = new Canvas(activity.getApplicationContext());
        localStreamView.setBackgroundColor(Color.BLACK);
        remoteStreamView.setBackgroundColor(Color.BLACK);

        final EventChannel _eventChannel = new EventChannel(binaryMessenger,
                Const.PEER_EVENT_CHANNEL_NAME + "/" + _peerId);
        //イベントチャネルからのコールバックインターフェースの実装
        EventChannel.StreamHandler eventChannelHandler = new EventChannel.StreamHandler() {
            @Override
            public void onListen(final Object arguments, final EventChannel.EventSink events) {
                if (DEBUG) Log.v(TAG, "onListen:" + events);
                synchronized (mSync) {
                    _eventSink = events;
                }
            }

            @Override
            public void onCancel(final Object arguments) {
                if (DEBUG) Log.v(TAG, "onCancel:" + arguments);
            }
        };
        _eventChannel.setStreamHandler(eventChannelHandler);

        // サーバーから切断する
        _peer.on(Peer.PeerEventEnum.DISCONNECTED, object -> {
            if (DEBUG) Log.v(TAG, "PeerEventEnum.DISCONNECTED:" + object);
            final Map<String, String> message = createMessage(Const.SkywayEvent.onClose);
            sendMessage(message);
        });

        // 相手からの通話を受ける
        _peer.on(Peer.PeerEventEnum.CALL, object -> {
            if (DEBUG) Log.v(TAG, "PeerEventEnum.Call:" + object);
            if (!(object instanceof MediaConnection)) {
                return;
            }
            _mediaConnection = (MediaConnection) object;
            createLocalStream();
            setMediaCallbacks(_mediaConnection);
            _mediaConnection.answer(_localStream);

            final Map<String, String> message
                    = createMessage(Const.SkywayEvent.onCall);
            message.put("from", _mediaConnection.peer());
            try {
                sendMessage(message);
            } catch (final Exception e) {
                Log.w(TAG, "PeerEventEnum.CAL: EventChannel is not ready or already released.", e);
            }
        });
    }

    public void call(@NonNull final String remotePeerId)
            throws IllegalStateException {

        if (DEBUG) Log.v(TAG, "startCall:" + remotePeerId);
        if (!isConnected()) {
            throw new IllegalStateException("Already released or not started local stream");
        }

        if (_mediaConnection != null) {
            _mediaConnection.close();
        }

        createLocalStream();
        final CallOption option = new CallOption();
        _mediaConnection = _peer.call(remotePeerId, _localStream, option);

        if (_mediaConnection != null) {
            setMediaCallbacks(_mediaConnection);
        }
    }

    public void listAllPeers(@NonNull OnListAllPeersCallback callback) {
        if (DEBUG) Log.v(TAG, "listAllPeers:");
        if (!isConnected()) {
            callback.onListAllPeers(Collections.emptyList());
        } else {
            // Get all IDs connected to the server
            _peer.listAllPeers(object -> {
                if (!(object instanceof JSONArray)) {
                    callback.onListAllPeers(Collections.emptyList());
                    return;
                }
                final JSONArray peers = (JSONArray) object;
                final List<String> peerIds = new ArrayList<>();
                String peerId;

                // Exclude my own ID
                for (int i = 0; peers.length() > i; i++) {
                    try {
                        peerId = peers.getString(i);
                        if (!_peerId.equals(peerId)) {
                            peerIds.add(peerId);
                        }
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }
                callback.onListAllPeers(peerIds);
            });
        }
    }

    public void enableAudio() {
        if(_localStream == null) {
            return;
        }
        final boolean isEnableAudio = _localStream.getEnableAudioTrack(0);
        _localStream.setEnableAudioTrack(0, !isEnableAudio);
    }

    public void enableVideo() {
        if(_localStream == null) {
            return;
        }
        final boolean isEnableVideo = _localStream.getEnableVideoTrack(0);
        _localStream.setEnableVideoTrack(0, !isEnableVideo);
    }

    public void switchCamera() {
        if(_localStream == null) {
            return;
        }
        _localStream.switchCamera();
    }

    //ローカル映像の取得開始
    public void createLocalStream()
            throws IllegalArgumentException {
        if (DEBUG) Log.v(TAG, "startLocalStream");
        Navigator.initialize(_peer);
        if (_localStream != null && localStreamView != null) {
            _localStream.removeVideoRenderer(localStreamView, 0);
        }
        if (_localStream == null) {
            final MediaConstraints constraints = new MediaConstraints();
            constraints.cameraPosition = MediaConstraints.CameraPositionEnum.FRONT;
            _localStream = Navigator.getUserMedia(constraints);
        }
        if (localStreamView != null) {
            _localStream.addVideoRenderer(localStreamView, 0);
        } else {
            throw new IllegalArgumentException("Specific local stream not found");
        }
    }

    public void setUpRemoteAudio() {
        final AudioManager audioManager = (AudioManager) _activity.getSystemService(Context.AUDIO_SERVICE);
        audioManager.setSpeakerphoneOn(true);
    }

    //リモート映像の取得開始
    public void setupRemoteStream(MediaStream _remoteStream)
            throws IllegalArgumentException {
        if (DEBUG) Log.v(TAG, "startRemoteStream");
        if (remoteStreamView != null) {
            this._remoteStream = _remoteStream;
            this._remoteStream.addVideoRenderer(remoteStreamView, 0);
        } else {
            throw new IllegalArgumentException("Specific remote stream not found");
        }
    }

    //MediaConnection.MediaEvents用コールバックをセット
    private void setMediaCallbacks(@NonNull final MediaConnection mediaConnection) {
        if (DEBUG) Log.v(TAG, "setMediaCallbacks:");
        // 相手のカメラ映像・マイク音声を受信したときのコールバックを設定
        mediaConnection.on(MediaConnection.MediaEventEnum.STREAM, object -> {
            if (DEBUG) Log.v(TAG, "MediaEventEnum.STREAM:" + object);
            if (object instanceof MediaStream) {
                setupRemoteStream((MediaStream) object);
                setUpRemoteAudio();
            }
        });
        // 相手がメディアコネクションの切断処理を実行し、実際に切断されたときのコールバックを設定
        mediaConnection.on(MediaConnection.MediaEventEnum.CLOSE, object -> {
            if (DEBUG) Log.v(TAG, "MediaEventEnum.CLOSE:" + object);
            if (object instanceof MediaConnection) {
                final MediaConnection remoteStream = (MediaConnection) object;
                remoteStream.close();
            }
            final Map<String, String> message
                    = createMessage(Const.SkywayEvent.onClose);
            try {
                sendMessage(message);
            } catch (final Exception e) {
                if (DEBUG) Log.w(TAG, e);
            }
        });

        // MediaConnectionでエラーが起こったときのコールバックを設定
        mediaConnection.on(MediaConnection.MediaEventEnum.ERROR, object -> {
            if (DEBUG) Log.d(TAG, "MediaEventEnum.ERROR:" + object);
            if (object instanceof PeerError) {
                final PeerError error = (PeerError) object;
                final Map<String, String> message
                        = createMessage(Const.SkywayEvent.onError);
                message.put("error", error.toString());
                try {
                    sendMessage(message);
                } catch (final Exception e) {
                    if (DEBUG) Log.w(TAG, e);
                }
            }
        });
    }

    private boolean isConnected() {
        return !_peer.isDestroyed() && !_peer.isDisconnected();
    }

    @NonNull
    private Map<String, String> createMessage(final Const.SkywayEvent event) {
        final Map<String, String> message = new HashMap<>();
        message.put("event", event.name());
        message.put("from", _peerId);
        return message;
    }

    //Dart側へイベントチャネルでイベントを送信する
    private void sendMessage(@NonNull final Map<String, String> message)
            throws IllegalStateException {

        synchronized (mSync) {
            if (_eventSink != null) {
                _eventSink.success(message);
            } else {
                throw new IllegalStateException("EventSink not ready or already released.");
            }
        }
    }

    //ピア接続を切断し関係するリソースを開放する
    public void destroy() {
        if (DEBUG) Log.v(TAG, "destroy:");
        if (_remoteStream != null) {
            if(remoteStreamView != null) {
                _remoteStream.removeVideoRenderer(remoteStreamView, 0);
                remoteStreamView = null;
            }
            _remoteStream.close();
            _remoteStream = null;
        }

        if (_localStream != null) {
            if (localStreamView != null) {
                _localStream.removeVideoRenderer(localStreamView, 0);
                localStreamView = null;
            }
            _localStream.close();
            _localStream = null;
        }

        if (_mediaConnection != null) {
            if (_mediaConnection.isOpen()) {
                _mediaConnection.close();
            }
            unsetMediaCallbacks(_mediaConnection);
            _mediaConnection = null;
        }

        Navigator.terminate();

        if (isConnected()) {
            unsetPeerCallback(_peer);
            if (!_peer.isDisconnected()) {
                _peer.disconnect();
            }

            if (!_peer.isDestroyed()) {
                _peer.destroy();
            }
        }
        if (_eventSink != null) {
            final Map<String, String> message
                    = createMessage(Const.SkywayEvent.onClose);
            sendMessage(message);
            _eventSink = null;
        }
    }

    //PeerEventsのためのコールバック設定を解除
    private void unsetPeerCallback(@NonNull Peer peer) {
        if (DEBUG) Log.v(TAG, "unsetPeerCallback:");
        peer.on(Peer.PeerEventEnum.OPEN, null);
        peer.on(Peer.PeerEventEnum.CONNECTION, null);
        peer.on(Peer.PeerEventEnum.CALL, null);
        peer.on(Peer.PeerEventEnum.CLOSE, null);
        peer.on(Peer.PeerEventEnum.DISCONNECTED, null);
        peer.on(Peer.PeerEventEnum.ERROR, null);
    }

    //MediaConnection.MediaEventsのためのコールバック設定を解除
    private void unsetMediaCallbacks(@NonNull final MediaConnection mediaConnection) {
        if (DEBUG) Log.v(TAG, "unsetMediaCallbacks:");
        mediaConnection.on(MediaConnection.MediaEventEnum.STREAM, null);
        mediaConnection.on(MediaConnection.MediaEventEnum.CLOSE, null);
        mediaConnection.on(MediaConnection.MediaEventEnum.ERROR, null);
    }
}