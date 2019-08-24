package xyz.track.track_me;

import android.os.Bundle;
import io.flutter.app.FlutterActivity;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FlutterActivity {
  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    GeneratedPluginRegistrant.registerWith(this);
    new MethodChannel(getFlutterView(), "android_app_retain").setMethodCallHandler((call, result) -> {
      if (call.method.equals("sendToBackground")) {
        moveTaskToBack(true);
      }
    });
  }
}
