package com.anasuddin.cannoncraze;

import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.FrameLayout;

import androidx.appcompat.app.AppCompatActivity;

import processing.android.CompatUtils;
import processing.android.PFragment;

public class MainActivity extends AppCompatActivity {
  private Sketch sketch;

  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);

    FrameLayout frame = new FrameLayout(this);
    frame.setId(CompatUtils.getUniqueViewId());
    setContentView(frame, new ViewGroup.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.MATCH_PARENT));

    // A game should not dim or lock mid-aim.
    getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

    sketch = new Sketch();
    PFragment fragment = new PFragment(sketch);
    fragment.setView(frame, this);
  }

  @Override
  public void onWindowFocusChanged(boolean hasFocus) {
    super.onWindowFocusChanged(hasFocus);
    if (hasFocus) enterImmersiveMode();
  }

  // Hide the status and navigation bars; swiping from an edge peeks them
  // temporarily, which is the expected behavior for a fullscreen game.
  private void enterImmersiveMode() {
    View decor = getWindow().getDecorView();
    if (Build.VERSION.SDK_INT >= 30) {
      android.view.WindowInsetsController c = decor.getWindowInsetsController();
      if (c != null) {
        c.setSystemBarsBehavior(
            android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
        c.hide(android.view.WindowInsets.Type.systemBars());
      }
    } else {
      decor.setSystemUiVisibility(
          View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        | View.SYSTEM_UI_FLAG_FULLSCREEN
        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
        | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);
    }
  }

  @Override
  @SuppressWarnings("deprecation")
  public void onBackPressed() {
    // The sketch walks back through its own screens (modal, run, menu) and
    // only asks the activity to finish from the main menu.
    if (sketch == null || !sketch.handleBack()) {
      super.onBackPressed();
    }
  }
}
