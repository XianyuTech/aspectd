package com.aspectd.example;

import com.growingio.android.sdk.autotrack.AutotrackConfiguration;
import com.growingio.android.sdk.autotrack.GrowingAutotracker;
import io.flutter.app.FlutterApplication;

public class MyApplication extends FlutterApplication {
    private static AutotrackConfiguration sConfiguration;
    @Override
    public void onCreate() {
        super.onCreate();


        if (sConfiguration == null) {
            sConfiguration = new AutotrackConfiguration("bfc5d6a3693a110d", "growing.d80871b41ef40518")
                    .setUploadExceptionEnabled(false)
                    .setDebugEnabled(true)
                    .setOaidEnabled(false);
        }
        GrowingAutotracker.startWithConfiguration(this, sConfiguration);
    }
}
