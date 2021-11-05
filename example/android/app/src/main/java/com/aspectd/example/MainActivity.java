package com.aspectd.example;

import android.content.Intent;
import android.os.Bundle;
import android.os.PersistableBundle;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.growingio.android.sdk.autotrack.GrowingAutotracker;

import io.flutter.Log;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.plugin.common.MethodChannel;

import com.aspectd.example.ui.login.LoginActivity;

public class MainActivity extends FlutterActivity {
    private final static String CHANNEL_NATIVE = "samples.flutter.dev/goToNativePage";
    private MethodChannel mMethodChannel;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // 初始化 MethodChannel
        mMethodChannel = new MethodChannel(getFlutterEngine().getDartExecutor().getBinaryMessenger(), CHANNEL_NATIVE);
        // Flutter 调用 android 的方法会执行到此回调
        mMethodChannel.setMethodCallHandler((call, result) -> {
            Log.e("xxxxx", "method = " + call.method);
            switch (call.method) {
                case "goToNativePage":
                    Intent intent = new Intent(MainActivity.this, LoginActivity.class);
                    startActivity(intent);
                    // 将结果回调给 Flutter
//                    result.success("我是来自Native的回调");
                    break;
            }
        });
    }

    @Override
    protected void onNewIntent(@NonNull Intent intent) {
        super.onNewIntent(intent);
        GrowingAutotracker.get().onActivityNewIntent(this, intent);
    }
}
