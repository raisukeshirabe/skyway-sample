package com.example.skyway_sample;

import android.content.Context;
import android.graphics.Color;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import org.jetbrains.annotations.NotNull;

import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;
import io.skyway.Peer.Browser.Canvas;

public class SkywayServiceFactory extends PlatformViewFactory {
    @NonNull
    private final BinaryMessenger messenger;

    public SkywayServiceFactory(@NotNull BinaryMessenger messenger) {
        super(StandardMessageCodec.INSTANCE);
        this.messenger = messenger;
    }

    @Override
    public PlatformView create(@NonNull Context context, int id, @Nullable Object args) {
        if (args instanceof HashMap) {
            @SuppressWarnings("unchecked")
            final HashMap<String, Object> creationParams = (HashMap<String, Object>) args;
            final Canvas view;
            view = switchView(context, creationParams);
            return new SkywayServiceView(view);
        }
        throw new IllegalStateException("args is null");
    }

    private Canvas switchView(Context context, Map<String, Object> creationParams) {
        final int id = (int) creationParams.get("id");
        if (id == 0) {
            return SkywayPeer.localStreamView;
        } else if (id == 1) {
            return SkywayPeer.remoteStreamView;
        } else {
            final Canvas errorView = new Canvas(context);
            errorView.setBackgroundColor(Color.RED);
            return errorView;
        }
    }
}