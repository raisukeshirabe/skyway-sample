package com.example.skyway_sample

internal object Const {
    /**
     * MainActivityで実装するメソッドチャネル名
     */
    const val METHOD_CHANNEL_NAME = "skyway_service"

    /**
     * 各ピア接続毎にFlutterSkywayPeerで実装するメソッドチャネルの～ベス名(実際には_$peerIdでポストフィックス)
     */
    const val PEER_EVENT_CHANNEL_NAME = "skyway_service"

    /**
     * FlutterSkywayCanvasクラスの登録名
     * "_${id}"をポストフィックスとして付加したものをsetter/getter用メソッドチャネル名として使用する
     */
    const val SKYWAY_SERVICE_VIEW = "skyway_service/video_view"

    enum class SkywayEvent {
        /**
         * ピア接続が切断された
         */
        onClose,
        /**
         * p2pで着呼した
         */
        onCall,
        /**
         * なにかのエラーが発生した
         */
        onError,
    }
}