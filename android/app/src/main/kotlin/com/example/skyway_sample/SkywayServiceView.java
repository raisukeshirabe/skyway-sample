package com.example.skyway_sample;

import android.view.View;;

import io.flutter.plugin.platform.PlatformView;
import io.skyway.Peer.Browser.Canvas;

public class SkywayServiceView implements PlatformView {

    private final Canvas view;

    SkywayServiceView(Canvas canvas) {
        view = canvas;
    }

    @Override
    public View getView() {
        return view;
    }

    @Override
    public void dispose() {
    }
}
