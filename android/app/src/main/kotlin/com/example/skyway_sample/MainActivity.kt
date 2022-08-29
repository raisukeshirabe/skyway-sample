package com.example.skyway_sample

import android.content.ContentValues
import android.util.Log
import androidx.annotation.NonNull
import com.example.skyway_sample.Const
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import io.skyway.Peer.*
import java.util.*

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        flutterEngine
                .platformViewsController
                .registry
                .registerViewFactory(Const.SKYWAY_SERVICE_VIEW,
                        SkywayServiceFactory(flutterEngine.dartExecutor.binaryMessenger))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, Const.METHOD_CHANNEL_NAME)
                .setMethodCallHandler { call, result -> onMethodCall(call, result) }
    }

    private var peers: MutableMap<String, SkywayPeer> = HashMap()

    private fun onMethodCall(methodCall: MethodCall, result: MethodChannel.Result) {
        when (methodCall.method) {
            "connect" -> {
                connect(methodCall, result)
            }
            "destroy" -> {
                destroy(methodCall, result)
            }
            "call" -> {
                call(methodCall, result)
            }
            "listAllPeers" -> {
                listAllPeers(methodCall, result)
            }
            "enableAudio" -> {
                enableAudio(methodCall, result)
            }
            "enableVideo" -> {
                enableVideo(methodCall, result)
            }
            "switchCamera" -> {
                switchCamera(methodCall, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun connect(methodCall: MethodCall, result: MethodChannel.Result) {
        val apiKey = methodCall.argument<String>("apiKey")
        val domain = methodCall.argument<String>("domain")
        val peerId = methodCall.argument<String>("peerId")
        if (apiKey != null && domain != null && peerId != null) {
            Log.d(ContentValues.TAG, "connect:domain=${domain},apiKey=${apiKey}")
            val option = PeerOption()
            option.key = apiKey
            option.domain = domain
            option.debug = Peer.DebugLevelEnum.ALL_LOGS
            // APIキーとドメインを設定しPeerクラスを生成
            val peer = Peer(this, peerId, option)

            // Skywayサーバーに接続
            peer.on(Peer.PeerEventEnum.OPEN) {
                val wrapped = SkywayPeer(this, peerId, peer, flutterEngine!!.dartExecutor.binaryMessenger)
                synchronized(peers) {
                    peers.put(peerId, wrapped)
                }
                Log.d(ContentValues.TAG, "[On/Close]")

                result.success(peerId)
            }
            peer.on(Peer.PeerEventEnum.ERROR) { `object` ->
                val error = `object` as PeerError
                Log.d(ContentValues.TAG, "[On/Error]" + error.message)
            }
            peer.on(Peer.PeerEventEnum.CLOSE) {
                synchronized(peers) {
                    peers.remove(peerId)?.destroy()
                }
                Log.d(ContentValues.TAG, "[On/Close]")
            }
        } else {
            result.error("InvalidArguments", "`apiKey` and `domain` and `peerId` must not be null.", null)
        }
    }

    private fun destroy(methodCall: MethodCall, result: MethodChannel.Result) {
        val peerId = methodCall.argument<String>("peerId")
        if (peerId != null) {
            synchronized(peers) {
                peers.remove<String?, SkywayPeer>(peerId)?.destroy()
            }
            result.success("success")
        }
    }

    private fun call(methodCall: MethodCall, result: MethodChannel.Result) {
        Log.d(ContentValues.TAG, "call: $methodCall")
        val peerId = methodCall.argument<String>("peerId")
        val targetPeerId = methodCall.argument<String>("targetPeerId")
        val peer = getPeer(peerId)
        if (peer != null && targetPeerId != null) {
            peer.call(targetPeerId)
            result.success("success")
        } else {
            result.error("PeerError", "failed to call", null)
        }
    }

    private fun listAllPeers(methodCall: MethodCall, result: MethodChannel.Result) {
        val peerId = methodCall.argument<String>("peerId")
        val peer = getPeer(peerId)
        if (peer != null) {
            peer.listAllPeers(SkywayPeer.OnListAllPeersCallback { list -> result.success(list) })
        } else {
            result.error("PeerError", "failed to call", null)
        }
    }

    private fun enableAudio(methodCall: MethodCall, result: MethodChannel.Result) {
        val peerId = methodCall.argument<String>("peerId")
        val peer = getPeer(peerId)
        if (peer != null) {
            peer.enableAudio()
            result.success("success")
        } else {
            result.error("InvalidArguments", "failed to enable audio", null)
        }
    }

    private fun enableVideo(methodCall: MethodCall, result: MethodChannel.Result) {
        val peerId = methodCall.argument<String>("peerId")
        val peer = getPeer(peerId)
        if (peer != null) {
            peer.enableVideo()
            result.success("success")
        } else {
            result.error("InvalidArguments", "failed to enable video", null)
        }
    }

    private fun switchCamera(methodCall: MethodCall, result: MethodChannel.Result) {
        val peerId = methodCall.argument<String>("peerId")
        val peer = getPeer(peerId)
        if (peer != null) {
            peer.switchCamera()
            result.success("success")
        } else {
            result.error("InvalidArguments", "failed to switch camera", null)
        }
    }

    private fun getPeer(peerId: String?) : SkywayPeer? {
        synchronized(peers) {
            return peers[peerId]
        }
    }
}