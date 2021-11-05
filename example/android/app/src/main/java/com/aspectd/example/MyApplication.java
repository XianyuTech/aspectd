package com.aspectd.example;

import com.growingio.android.sdk.autotrack.CdpAutotrackConfiguration;
import com.growingio.android.sdk.autotrack.GrowingAutotracker;
import io.flutter.app.FlutterApplication;

public class MyApplication extends FlutterApplication {
    @Override
    public void onCreate() {
        super.onCreate();
        GrowingAutotracker.startWithConfiguration(this, new CdpAutotrackConfiguration("91eaf9b283361032", "growing.2f3e1e11e001c55e")
                .setDataCollectionServerHost("https://run.mocky.io/v3/08999138-a180-431d-a136-051f3c6bd306")
                .setDataSourceId("8deb3a4737d7aa00")
                .setUploadExceptionEnabled(false)
                .setDebugEnabled(true));


    }
}
