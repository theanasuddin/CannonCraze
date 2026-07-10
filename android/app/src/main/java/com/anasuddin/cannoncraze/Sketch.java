package com.anasuddin.cannoncraze;

import android.app.Activity;
import android.content.Context;
import android.content.SharedPreferences;

import java.util.ArrayList;

import processing.core.PApplet;
import processing.core.PFont;
import processing.core.PGraphics;
import processing.core.PShape;

/**
 * Cannon Craze, Android edition.
 *
 * A direct port of the desktop Processing sketch: one class, organized in the
 * same sections as the desktop tabs (Theme, Viewport, Background, Gameplay,
 * Menu, Ui, Particles, Sound, Persistence). Gameplay geometry, palette, and
 * physics are identical; only the platform glue differs:
 *
 *   - fullscreen P2D surface instead of a resizable window
 *   - touch input (single pointer maps to the mouse callbacks)
 *   - SharedPreferences instead of text files
 *   - an AudioTrack mixer (SoundEngine) instead of javax.sound
 *   - the system back gesture walks modal, then run, then exits
 */
public class Sketch extends PApplet {

  // -- Renderer / safe mode -----------------------------------------------------------
  // Normal launches use P2D (OpenGL ES). If MainActivity saw the previous
  // launches die before the first frame (a GPU that refuses the GL surface),
  // it constructs the sketch in safe mode: the software canvas renderer plus
  // conservative visual quality. Slower, but it opens everywhere.

  private final boolean safeMode;

  public Sketch(boolean safeMode) {
    this.safeMode = safeMode;
  }

  public Sketch() {
    this(false);
  }

  // -- Screens / flow ---------------------------------------------------------------

  static final int SCREEN_MENU = 0;
  static final int SCREEN_PLAY = 1;

  static final int MODAL_NONE     = 0;
  static final int MODAL_SETTINGS = 1;
  static final int MODAL_HELP     = 2;
  static final int MODAL_CREDITS  = 3;

  int screenId = SCREEN_MENU;
  int modalId  = MODAL_NONE;

  // -- Gameplay constants -----------------------------------------------------------

  static final float CANNON_X     = 126;    // barrel pivot / launch origin
  static final float CANNON_Y     = 380;
  static final float PLATFORM_TOP = 392;
  static final float BARREL_LEN   = 46;
  static final float MAX_DRAG     = 160;    // px of pull == launch velocity
  static final float GRAVITY      = 16;

  static final int BALL_RADIUS_MIN = 5;
  static final int BALL_RADIUS_MAX = 15;

  static final float TARGET_X     = 220;
  static final float TARGET_W     = 660;
  static final float TARGET_RIGHT = TARGET_X + TARGET_W;
  static final float TARGET_ROW_Y = 552;
  static final float TARGET_H     = 16;
  static final int   TARGETS_MIN  = 5;
  static final int   TARGETS_MAX  = 15;

  // Touch needs a more generous grab zone than a mouse pointer.
  static final float GRAB_RADIUS_MIN = 44;

  // -- Game state -------------------------------------------------------------------

  int     score       = 0;
  int     highScore   = 0;
  boolean isGameOver  = false;
  boolean isNewRecord = false;

  // Settings
  float   ballRadius      = 12;
  int     targetCount     = 10;
  boolean guidelineHidden = false;
  boolean soundOn         = true;
  float   soundVolume     = 0.8f;   // 0..1 master volume

  // Ball / physics
  float   angle      = 0;      // pull angle (ball dragged down-left of the pivot)
  float   velocity   = 0;
  float   flightTime = 0;
  float   flightAcc  = 0;      // real-time accumulator driving fixed flight steps
  boolean isAiming   = false;
  boolean isInFlight = false;
  float   aimX, aimY;          // ghost-ball position while aiming
  float   barrelAngle = -QUARTER_PI;
  float   recoilT     = 0;

  // Targets
  int   targetIndex = 0;
  float padFlash    = 0;       // white flash on the pad that was just hit
  float padFlashX, padFlashW;

  // Animation state
  float scorePop = 0;
  float shakeT   = 0;
  float fadeT    = 1;          // fade-in after a screen switch
  float overlayT = 0;          // game-over overlay entrance
  float modalT   = 0;          // modal entrance

  float centreX, centreY;

  // -- Setup / draw -----------------------------------------------------------------

  @Override
  public void settings() {
    fullScreen(safeMode ? JAVA2D : P2D);
  }

  @Override
  public void setup() {
    frameRate(60);

    centreX = VIEW_W / 2.0f;
    centreY = VIEW_H / 2.0f;

    if (safeMode) {
      // Software canvas: start frugal, let the governor climb if it can.
      gfxTier    = GFX_LOW;
      gfxTierMax = GFX_MED;
    }

    loadTheme();
    initUi();
    initParticles();

    loadPersistent();
    initSound();
  }

  @Override
  public void draw() {
    updateClock();
    updatePerfGovernor();
    confirmBootOnce();
    updateViewport();

    beginViewport();

    if (screenId == SCREEN_MENU) drawMenu();
    else                         drawGameplay();

    if (modalId != MODAL_NONE) drawModal();

    if (fadeT > 0.004f) {
      fadeT = lerp(fadeT, 0, expK(0.16f));
      pushStyle();
      rectMode(CORNER);
      noStroke();
      fill(SKY_TOP, 255 * fadeT);
      rect(worldLeft(), worldTop(), worldW, worldH);
      popStyle();
    }

    endViewport();
  }

  float tSec() {
    return millis() / 1000.0f;
  }

  // The first frames made it to the screen: this launch is healthy. Clear the
  // boot flag MainActivity set, so the safe-mode fallback stays armed only for
  // launches that actually die before drawing.
  boolean bootConfirmed = false;

  void confirmBootOnce() {
    if (bootConfirmed || frameCount < 3) return;
    bootConfirmed = true;
    try {
      Activity a = getActivity();
      if (a != null) {
        a.getSharedPreferences(MainActivity.BOOT_PREFS, Context.MODE_PRIVATE)
         .edit()
         .putBoolean(MainActivity.KEY_BOOTING, false)
         .putInt(MainActivity.KEY_FAIL_COUNT, 0)
         .apply();
      }
    } catch (Exception e) {
      // Never let bookkeeping take the game down.
    }
  }

  // ===================================================================================
  // Performance: real-time clock + adaptive quality governor
  // ===================================================================================
  // The clock measures real time between frames so all motion advances by the
  // true delta: a phone stuck at 40 fps drops frames instead of playing in
  // slow motion, and a 120 Hz display never fast-forwards. The governor
  // watches the smoothed frame rate and steps the decoration tier down (or
  // back up): star count, glow passes, light-column slices, particle counts.
  // Gameplay geometry, physics, and difficulty are identical at every tier.

  float dtSec = 1 / 60.0f;  // real seconds since the previous frame, clamped
  float nf    = 1;          // normalized frames: dtSec * 60 (1.0 at exactly 60 fps)
  long  lastFrameMs = -1;
  float fpsAvg = 60;        // exponentially smoothed fps for the governor

  void updateClock() {
    long now = millis();
    if (lastFrameMs < 0) lastFrameMs = now - 16;
    float raw = (now - lastFrameMs) / 1000.0f;
    lastFrameMs = now;
    if (raw > 0.0001f) fpsAvg = lerp(fpsAvg, min(1.0f / raw, 240), 0.06f);
    dtSec = constrain(raw, 1 / 240.0f, 1 / 20.0f);
    nf    = dtSec * 60;
  }

  // Converts a per-frame lerp factor (tuned at 60 fps) into its frame-rate
  // independent equivalent, so easing settles in the same wall-clock time
  // everywhere.
  float expK(float k) {
    return 1 - pow(1 - k, nf);
  }

  static final int GFX_LOW  = 0;
  static final int GFX_MED  = 1;
  static final int GFX_HIGH = 2;

  int     gfxTier    = GFX_HIGH;
  int     gfxTierMax = GFX_HIGH;   // capped when a raise immediately falls back
  boolean lastChangeWasRaise = false;
  float   tierHoldT  = 0;          // seconds since the tier last changed
  float   raiseOkT   = 0;          // continuous seconds of comfortable fps

  void updatePerfGovernor() {
    tierHoldT += dtSec;
    if (millis() < 2500) return;   // ignore startup jank while caches warm

    if (fpsAvg > 57) raiseOkT += dtSec;
    else             raiseOkT = 0;

    if (fpsAvg < 48 && gfxTier > GFX_LOW && tierHoldT > 2) {
      // A drop right after a raise means the higher tier does not fit: stop
      // offering it, otherwise the tiers oscillate.
      if (lastChangeWasRaise && tierHoldT < 12) gfxTierMax = gfxTier - 1;
      gfxTier--;
      lastChangeWasRaise = false;
      tierHoldT = 0;
    } else if (raiseOkT > 6 && gfxTier < gfxTierMax) {
      gfxTier++;
      lastChangeWasRaise = true;
      tierHoldT = 0;
      raiseOkT  = 0;
    }
  }

  // Quality knobs: everything below is decoration only; gameplay never reads these.

  float qStarFrac()     { return gfxTier == GFX_HIGH ? 1.0f : (gfxTier == GFX_MED ? 0.55f : 0.3f); }
  boolean qSparkles()   { return gfxTier == GFX_HIGH; }
  boolean qMeteor()     { return gfxTier != GFX_LOW; }
  int   qGlowPasses()   { return gfxTier == GFX_HIGH ? 4 : (gfxTier == GFX_MED ? 2 : 1); }
  int   qLinePasses()   { return gfxTier == GFX_HIGH ? 3 : (gfxTier == GFX_MED ? 2 : 1); }
  int   qColumnSlices() { return gfxTier == GFX_HIGH ? 30 : (gfxTier == GFX_MED ? 16 : 8); }
  float qBurstFrac()    { return gfxTier == GFX_HIGH ? 1.0f : (gfxTier == GFX_MED ? 0.7f : 0.5f); }
  int   qTrailEvery()   { return gfxTier == GFX_LOW ? 2 : 1; }

  // -- Input (single touch maps to the mouse callbacks) ------------------------------

  @Override
  public void mousePressed() {
    syncCanvasMouse();

    if (modalId != MODAL_NONE) {
      handleModalClick();
    } else if (screenId == SCREEN_MENU) {
      handleMenuClick();
    } else if (isGameOver) {
      handleGameOverClick();
    } else if (!isInFlight && overGrabZone()) {
      isAiming = true;
      sfxGrab();
    }
  }

  @Override
  public void mouseDragged() {
    if (sldVolume != null && sldVolume.dragging) {
      syncCanvasMouse();
      sldVolume.setFromMouse(vmx);
    }
  }

  @Override
  public void mouseReleased() {
    if (sldVolume != null && sldVolume.dragging) {
      sldVolume.dragging = false;
      savePersistent();
      return;
    }
    if (!isAiming) return;
    isAiming = false;
    if (velocity > 4) launch();   // a tiny nudge cancels instead of firing
  }

  // System back gesture: modal first, then the run, then let the activity exit.
  public boolean handleBack() {
    if (modalId != MODAL_NONE) {
      closeModal();
      return true;
    }
    if (screenId == SCREEN_PLAY) {
      toMenu();
      return true;
    }
    return false;
  }

  void exitToSystem() {
    Activity a = getActivity();
    if (a != null) a.finish();
  }

  // -- Game flow --------------------------------------------------------------------

  void startGame() {
    screenId    = SCREEN_PLAY;
    score       = 0;
    isGameOver  = false;
    isNewRecord = false;
    scorePop    = 0;
    fadeT       = 1;
    targetIndex = -1;
    clearParticles();
    nextRound();
  }

  void toMenu() {
    screenId   = SCREEN_MENU;
    isAiming   = false;
    isInFlight = false;
    isGameOver = false;
    fadeT      = 1;
    clearParticles();
  }

  void nextRound() {
    angle      = 0;
    velocity   = 0;
    flightTime = 0;
    flightAcc  = 0;
    isAiming   = false;
    isInFlight = false;

    int next = targetIndex;
    while (next == targetIndex && targetCount > 1) {
      next = (int) random(targetCount);
    }
    targetIndex = max(0, next);
  }

  void launch() {
    isInFlight = true;
    flightTime = 0;
    flightAcc  = 0;
    recoilT    = 1;
    spawnBurst(muzzleX(), muzzleY(), ACCENT, 10, 2.2f);
    sfxLaunch();
  }

  void endFlight() {
    isInFlight = false;
    flightTime = 0;
    flightAcc  = 0;
  }

  void triggerGameOver() {
    isGameOver  = true;
    overlayT    = 0;
    shakeT      = 1;
    isNewRecord = score > highScore;
    if (isNewRecord) {
      highScore = score;
      savePersistent();
      spawnRecordBurst(centreX, centreY - 130);
      sfxRecord();
    } else {
      sfxGameOver();
    }
  }

  void handleGameOverClick() {
    if (btnAgain.contains(vmx, vmy)) {
      sfxClick();
      startGame();
    } else if (btnMenuOver.contains(vmx, vmy)) {
      sfxClick();
      toMenu();
    }
  }

  // -- Lifecycle ----------------------------------------------------------------------

  @Override
  public void onResume() {
    super.onResume();
    if (sndEngine != null) sndEngine.setActive(true);
    bgSceneW = -1;   // the GL context may have been recreated: rebuild the scene
  }

  @Override
  public void onPause() {
    if (sndEngine != null) sndEngine.setActive(false);
    super.onPause();
  }

  @Override
  public void onDestroy() {
    if (sndEngine != null) sndEngine.release();
    super.onDestroy();
  }

  // ===================================================================================
  // Theme: design system (palette, typography, drawing primitives)
  // ===================================================================================

  // Ink
  static final int INK       = 0xFFEEF1FF;
  static final int INK_DIM   = 0xFF9AA2C8;
  static final int INK_FAINT = 0xFF565C86;

  // Brand
  static final int ACCENT      = 0xFF2FE8D8;
  static final int ACCENT_SOFT = 0xFF8FF7EC;
  static final int ACCENT_DEEP = 0xFF0FA89B;
  static final int VIOLET      = 0xFF7B6CFF;
  static final int CORAL       = 0xFFFF6E7E;
  static final int GOLD        = 0xFFFFC96B;

  // Scene
  static final int SKY_TOP     = 0xFF030210;
  static final int SKY_MID     = 0xFF0A0733;
  static final int SKY_HORIZON = 0xFF1A1156;
  static final int MOUNT_FAR   = 0xFF110B38;
  static final int MOUNT_NEAR  = 0xFF0A0626;
  static final int GROUND      = 0xFF070414;

  // Surfaces
  static final int PANEL_BG      = 0xFF0B0A26;
  static final int PANEL_LINE    = 0xFF7E86CD;
  static final int METAL_LIGHT   = 0xFF191349;   // cannon dome
  static final int BTN_TEXT_DARK = 0xFF04222B;   // text on filled accent buttons

  PFont fontRegular, fontBold, fontScript;

  PShape shapeLogo;   // cannon glyph, style disabled so it can be tinted

  void loadTheme() {
    // No single missing or corrupt asset is allowed to stop the game from
    // opening: fonts fall back to the system sans, the glyph to a plain crest.
    try {
      fontRegular = createFont("Montserrat-Regular.otf", 96);
      fontBold    = createFont("Montserrat-Bold.otf",    96);
      fontScript  = createFont("Playlist-Script.otf",    96);
    } catch (Exception e) {
      e.printStackTrace();
    }
    if (fontRegular == null) fontRegular = createFont("SansSerif", 96);
    if (fontBold    == null) fontBold    = fontRegular;
    if (fontScript  == null) fontScript  = fontRegular;

    try {
      PShape svg   = loadShape("logo.svg");
      PShape child = svg.getChild("Layer 1");
      if (child == null) child = svg.getChild("Layer_1");
      shapeLogo = (child != null) ? child : svg;
      shapeLogo.disableStyle();
    } catch (Exception e) {
      shapeLogo = null;   // drawMenuLogo falls back to a plain crest
    }
  }

  float easeOutCubic(float p) {
    return 1 - pow(1 - constrain(p, 0, 1), 3);
  }

  // Tracked (letter-spaced) text. Set textFont/textSize before calling.

  float trackedWidth(String s, float tracking) {
    float w = 0;
    for (int i = 0; i < s.length(); i++) {
      w += textWidth(s.charAt(i));
      if (i < s.length() - 1) w += tracking;
    }
    return w;
  }

  void trackedTextL(String s, float x, float y, float tracking) {
    pushStyle();
    textAlign(LEFT, CENTER);
    float cx = x;
    for (int i = 0; i < s.length(); i++) {
      char c = s.charAt(i);
      text(c, cx, y);
      cx += textWidth(c) + tracking;
    }
    popStyle();
  }

  void trackedTextC(String s, float x, float y, float tracking) {
    trackedTextL(s, x - trackedWidth(s, tracking) / 2, y, tracking);
  }

  void trackedTextR(String s, float x, float y, float tracking) {
    trackedTextL(s, x - trackedWidth(s, tracking), y, tracking);
  }

  // Glow primitives

  // Both glow primitives honor the quality governor: lower tiers draw fewer
  // halo passes, keeping the bright core and shedding the faint outer layers.
  void glowCircle(float x, float y, float r, int c, float strength) {
    pushStyle();
    noStroke();
    for (int i = qGlowPasses(); i >= 1; i--) {
      fill(c, strength / (i * i));
      circle(x, y, (r + i * i * 2.4f) * 2);
    }
    popStyle();
  }

  void glowLine(float x1, float y1, float x2, float y2, int c, float coreW, float strength) {
    pushStyle();
    for (int i = qLinePasses(); i >= 1; i--) {
      stroke(c, strength / (i * i + 1));
      strokeWeight(coreW + i * i * 2.0f);
      line(x1, y1, x2, y2);
    }
    stroke(c, min(255, strength * 1.7f));
    strokeWeight(coreW);
    line(x1, y1, x2, y2);
    popStyle();
  }

  // Panel (glass card)

  void drawPanel(float cx, float cy, float w, float h, float r, float alphaMul) {
    pushStyle();
    rectMode(CENTER);
    noStroke();
    fill(0, 46 * alphaMul);
    rect(cx, cy + 6, w + 16, h + 16, r + 8);
    fill(0, 80 * alphaMul);
    rect(cx, cy + 9, w, h, r);

    fill(PANEL_BG, 253 * alphaMul);
    stroke(PANEL_LINE, 78 * alphaMul);
    strokeWeight(1.2f);
    rect(cx, cy, w, h, r);

    stroke(255, 15 * alphaMul);
    strokeWeight(1);
    line(cx - w / 2 + r, cy - h / 2 + 1.2f, cx + w / 2 - r, cy - h / 2 + 1.2f);
    popStyle();
  }

  // ===================================================================================
  // Viewport: the fullscreen display filled edge to edge
  // ===================================================================================
  // The game is designed on a 960 x 600 canvas. The canvas scales uniformly to
  // the largest size that fits the display, and the world extends past the
  // design region (more sky, wider mountains, longer ground) so the scene fills
  // every pixel of any screen, notch to notch. Gameplay geometry stays fixed
  // and centred, so the game plays identically on every device.

  static final int VIEW_W = 960;
  static final int VIEW_H = 600;

  float viewS  = 1;        // display to canvas scale (uniform)
  float offX   = 0;        // how far the world extends past the design region,
  float offY   = 0;        // per side, in canvas units
  float worldW = VIEW_W;   // full display size in canvas units
  float worldH = VIEW_H;
  float vmx    = 0;        // touch position in canvas coordinates
  float vmy    = 0;

  void updateViewport() {
    viewS = min(width / (float) VIEW_W, height / (float) VIEW_H);
    if (viewS <= 0) viewS = 1;
    worldW = width  / viewS;
    worldH = height / viewS;
    offX   = (worldW - VIEW_W) / 2;
    offY   = (worldH - VIEW_H) / 2;
    if (width != bgSceneW || height != bgSceneH) rebuildBackground();
    syncCanvasMouse();
  }

  float worldLeft()   { return -offX; }
  float worldRight()  { return VIEW_W + offX; }
  float worldTop()    { return -offY; }
  float worldBottom() { return VIEW_H + offY; }

  void syncCanvasMouse() {
    vmx = mouseX / viewS - offX;
    vmy = mouseY / viewS - offY;
  }

  void beginViewport() {
    // The static scene buffer is exactly display-sized: blit it 1:1 in screen
    // space before the world transform. It doubles as the background clear.
    if (bgScene != null) image(bgScene, 0, 0);
    else                 background(SKY_TOP);
    pushMatrix();
    scale(viewS);
    translate(offX, offY);
  }

  void endViewport() {
    popMatrix();
  }

  // ===================================================================================
  // Background: night-sky scene shared by every screen
  // ===================================================================================

  PGraphics bgScene;
  int bgSceneW = -1;   // display size the buffer was rendered at; -1 forces a build
  int bgSceneH = -1;

  static final int STAR_COUNT = 220;
  int starCount = 0;
  float[] starX  = new float[STAR_COUNT];
  float[] starY  = new float[STAR_COUNT];
  float[] starSz = new float[STAR_COUNT];
  float[] starPh = new float[STAR_COUNT];
  float[] starSp = new float[STAR_COUNT];

  static final float PLANET_X = 756, PLANET_Y = 128, PLANET_R = 58;

  // Meteor
  boolean mtActive = false;
  float   mtX, mtY, mtVX, mtVY, mtAge, mtLife;
  float   meteorTimer = 5;

  void rebuildBackground() {
    int pw = max(1, width);
    int ph = max(1, height);
    bgScene = createGraphics(pw, ph);
    bgScene.beginDraw();

    // Sky gradient, one horizontal band per pixel row, mapped through the
    // viewport so the horizon stays glued to the design region.
    bgScene.noFill();
    for (int y = 0; y < ph; y++) {
      float f = constrain((y / viewS - offY) / VIEW_H, 0, 1);
      int c = (f < 0.55f)
        ? lerpColor(SKY_TOP, SKY_MID, f / 0.55f)
        : lerpColor(SKY_MID, SKY_HORIZON, (f - 0.55f) / 0.45f);
      bgScene.stroke(c);
      bgScene.line(0, y, pw, y);
    }
    bgScene.noStroke();

    bgScene.pushMatrix();
    bgScene.scale(viewS);
    bgScene.translate(offX, offY);

    radialGlow(bgScene, 240, 130, 330, VIOLET, 8);
    radialGlow(bgScene, 820, 330, 380, ACCENT_DEEP, 6);

    drawPlanet(bgScene, PLANET_X, PLANET_Y, PLANET_R);

    noiseSeed(11);
    drawRidge(bgScene, 452, 62, 0.0042f, 0,  MOUNT_FAR);
    drawRidge(bgScene, 516, 48, 0.0060f, 57, MOUNT_NEAR);
    bgScene.noStroke();
    bgScene.fill(GROUND);
    bgScene.rect(worldLeft() - 2, 568, worldW + 4, worldBottom() - 568 + 2);

    bgScene.popMatrix();
    bgScene.endDraw();
    bgSceneW = pw;
    bgSceneH = ph;

    rebuildStars();
  }

  void rebuildStars() {
    randomSeed(7);
    float wl = worldLeft(), wr = worldRight(), wt = worldTop();
    float area = (wr - wl) * (430 - wt);
    starCount = constrain(round(area / (960.0f * 430.0f) * 150), 40, STAR_COUNT);
    for (int i = 0; i < starCount; i++) {
      float x, y;
      do {
        x = random(wl, wr);
        y = random(wt, 430);
      } while (dist(x, y, PLANET_X, PLANET_Y) < PLANET_R * 2.4f);
      starX[i]  = x;
      starY[i]  = y;
      starSz[i] = random(0.8f, 2.4f);
      starPh[i] = random(TWO_PI);
      starSp[i] = random(0.5f, 1.6f);
    }
    randomSeed(System.currentTimeMillis());
  }

  void radialGlow(PGraphics g, float x, float y, float r, int c, float coreAlpha) {
    g.noStroke();
    int steps = 24;
    for (int i = steps; i >= 1; i--) {
      float f = i / (float) steps;
      g.fill(c, coreAlpha * (1 - f) * (1 - f) + 0.4f);
      g.circle(x, y, 2 * r * f);
    }
  }

  void drawPlanet(PGraphics g, float x, float y, float r) {
    radialGlow(g, x, y, r * 2.6f, ACCENT, 9);

    g.pushMatrix();
    g.translate(x, y);
    g.rotate(radians(-16));
    g.noFill();
    g.stroke(ACCENT_SOFT, 60);
    g.strokeWeight(1.5f);
    g.arc(0, 0, r * 3.5f, r * 1.05f, PI, TWO_PI);   // ring, far side
    g.popMatrix();

    g.noStroke();
    g.fill(0xFF171150);
    g.circle(x, y, r * 2);

    // rim light on the side facing the scene
    g.noFill();
    g.stroke(ACCENT, 120);
    g.strokeWeight(2);
    g.arc(x, y, r * 2 - 2, r * 2 - 2, HALF_PI + 0.5f, PI + 1.1f);

    g.pushMatrix();
    g.translate(x, y);
    g.rotate(radians(-16));
    g.noFill();
    g.stroke(ACCENT_SOFT, 110);
    g.strokeWeight(1.5f);
    g.arc(0, 0, r * 3.5f, r * 1.05f, 0, PI);        // ring, near side
    g.popMatrix();
  }

  void drawRidge(PGraphics g, float baseY, float amp, float freq, float seedOff, int c) {
    float wl = worldLeft() - 2, wr = worldRight() + 2, wb = worldBottom() + 2;
    g.noStroke();
    g.fill(c);
    g.beginShape();
    g.vertex(wl, wb);
    for (float x = wl; x <= wr; x += 5) {
      // +2000 keeps the noise domain positive, so wide screens never hit the
      // mirror fold Processing's noise() applies at zero
      g.vertex(x, baseY - noise((x + 2000) * freq + seedOff) * amp);
    }
    g.vertex(wr, wb);
    g.endShape(CLOSE);
  }

  // Per-frame layer: the static buffer blits in beginViewport, so only the
  // animated layers draw here.

  void drawBackground() {
    drawStars();
    updateMeteor();
  }

  void drawStars() {
    pushStyle();
    noStroke();
    float t = tSec();
    // Lower quality tiers draw a thinner (but stable) subset of the field.
    int shown = max(1, round(starCount * qStarFrac()));
    boolean sparkles = qSparkles();
    for (int i = 0; i < shown; i++) {
      float tw = 0.6f + 0.4f * sin(t * starSp[i] * 2.2f + starPh[i]);
      float a  = (60 + 130 * (starSz[i] / 2.4f)) * tw;
      fill(0xFFDDE6FF, a);
      circle(starX[i], starY[i], starSz[i]);
      if (sparkles && i % 19 == 0) {
        stroke(0xFFDDE6FF, a * 0.35f);
        strokeWeight(0.8f);
        float f = 2.2f + starSz[i] * 1.6f;
        line(starX[i] - f, starY[i], starX[i] + f, starY[i]);
        line(starX[i], starY[i] - f, starX[i], starY[i] + f);
        noStroke();
      }
    }
    popStyle();
  }

  void updateMeteor() {
    if (!qMeteor()) { mtActive = false; return; }

    if (!mtActive) {
      meteorTimer -= dtSec;
      if (meteorTimer <= 0) {
        mtActive = true;
        mtX    = random(300, worldRight() - 20);
        mtY    = random(worldTop() + 20, 130);
        float sp = random(6, 9);
        mtVX   = -sp * 0.92f;
        mtVY   =  sp * 0.40f;
        mtAge  = 0;
        mtLife = random(0.7f, 1.1f);
      }
      return;
    }

    mtAge += dtSec;
    mtX   += mtVX * nf;
    mtY   += mtVY * nf;
    if (mtAge >= mtLife) {
      mtActive    = false;
      meteorTimer = random(6, 13);
      return;
    }

    float u = mtAge / mtLife;
    float a = 180 * sin(u * PI);
    pushStyle();
    for (int k = 0; k < 6; k++) {
      float f = k / 6.0f;
      stroke(0xFFDDE6FF, a * (1 - f));
      strokeWeight(1.6f - f);
      line(mtX - mtVX * f * 4,          mtY - mtVY * f * 4,
           mtX - mtVX * (f + 0.16f) * 4, mtY - mtVY * (f + 0.16f) * 4);
    }
    noStroke();
    fill(0xFFFFFFFF, a);
    circle(mtX, mtY, 2.2f);
    popStyle();
  }

  // ===================================================================================
  // Gameplay: cannon, aiming, flight, targets, HUD, game-over overlay
  // ===================================================================================

  void drawGameplay() {
    drawBackground();

    pushMatrix();
    if (shakeT > 0.01f) {
      float m = 7 * shakeT * shakeT;
      translate(random(-m, m), random(-m, m));
      shakeT = lerp(shakeT, 0, expK(0.09f));
    }

    if (isAiming) updateAim();

    drawTargets();
    drawPlatform();
    if (isAiming && !guidelineHidden) drawTrajectory();
    drawCannon();

    if      (isInFlight) updateProjectile();
    else if (isAiming)   drawAimUI();
    else if (!isGameOver) drawIdleBall();

    if (!isGameOver) updateParticles();   // when game over, the overlay draws them
    popMatrix();

    drawHUD();
    drawReadouts();

    if (isGameOver) drawGameOverOverlay();
  }

  // -- Platform / cannon --------------------------------------------------------------

  void drawPlatform() {
    // The platform pours out to the world's left and bottom edges so wide or
    // tall screens never show a floating slab.
    float wl = worldLeft() - 2;
    float wb = worldBottom() + 2;
    float slantX = 168 + (232 - 168) / (VIEW_H + 2 - PLATFORM_TOP) * (wb - PLATFORM_TOP);

    pushStyle();
    noStroke();
    fill(0xFF0D0A2C);
    quad(wl, PLATFORM_TOP, 168, PLATFORM_TOP, slantX, wb, wl, wb);
    glowLine(wl, PLATFORM_TOP, 168, PLATFORM_TOP, ACCENT, 1.4f, 70);
    stroke(ACCENT, 36);
    strokeWeight(1.2f);
    line(168, PLATFORM_TOP, slantX, wb);
    popStyle();
  }

  void drawCannon() {
    float targetA = isAiming ? angle - PI : (isInFlight ? barrelAngle : -QUARTER_PI);
    barrelAngle = lerp(barrelAngle, targetA, expK(0.3f));
    recoilT     = max(0, recoilT - 0.07f * nf);

    pushStyle();
    pushMatrix();
    translate(CANNON_X, CANNON_Y);
    rotate(barrelAngle);
    translate(-6 * easeOutCubic(recoilT), 0);

    rectMode(CORNER);
    fill(0xFF1D1852);
    stroke(PANEL_LINE, 165);
    strokeWeight(1.3f);
    rect(-10, -9, BARREL_LEN + 12, 18, 9);

    stroke(255, 30);
    strokeWeight(1);
    line(-4, -5.5f, BARREL_LEN - 6, -5.5f);

    noStroke();
    fill(ACCENT, 220 + 35 * recoilT);
    rect(BARREL_LEN - 3, -9, 4.5f, 18, 2);
    popMatrix();

    noStroke();
    fill(METAL_LIGHT);
    arc(CANNON_X, PLATFORM_TOP + 2, 56, 56, PI, TWO_PI);
    noFill();
    stroke(ACCENT, 70);
    strokeWeight(1.3f);
    arc(CANNON_X, PLATFORM_TOP + 2, 56, 56, PI, TWO_PI);
    popStyle();
  }

  float muzzleX() { return CANNON_X + cos(barrelAngle) * BARREL_LEN; }
  float muzzleY() { return CANNON_Y + sin(barrelAngle) * BARREL_LEN; }

  float restBallX() { return CANNON_X + cos(barrelAngle) * (BARREL_LEN + ballRadius * 0.4f); }
  float restBallY() { return CANNON_Y + sin(barrelAngle) * (BARREL_LEN + ballRadius * 0.4f); }

  boolean overGrabZone() {
    return !isGameOver
        && dist(vmx, vmy, restBallX(), restBallY()) <= max(ballRadius + 12, GRAB_RADIUS_MIN);
  }

  // -- Ball rendering -------------------------------------------------------------

  void drawBall(float x, float y) {
    pushStyle();
    glowCircle(x, y, ballRadius, ACCENT, 90);
    noStroke();
    fill(ACCENT);
    circle(x, y, ballRadius * 2);
    fill(0xFFEAFFFC, 210);
    circle(x - ballRadius * 0.28f, y - ballRadius * 0.32f, ballRadius * 0.85f);
    popStyle();
  }

  void drawIdleBall() {
    float bx = restBallX(), by = restBallY();
    drawBall(bx, by);

    float pu = 0.5f + 0.5f * sin(tSec() * 2.4f);
    pushStyle();
    noFill();
    stroke(ACCENT, 50 + 60 * pu);
    strokeWeight(1.4f);
    circle(bx, by, ballRadius * 2 + 11 + 4 * pu);
    popStyle();
  }

  // -- Aiming ---------------------------------------------------------------------

  void updateAim() {
    float ax = min(vmx, CANNON_X - 0.01f);
    float ay = max(vmy, CANNON_Y + 0.01f);

    angle = atan2(ay - CANNON_Y, ax - CANNON_X);
    float d = dist(ax, ay, CANNON_X, CANNON_Y);
    if (d > MAX_DRAG) {
      ax = CANNON_X + MAX_DRAG * cos(angle);
      ay = CANNON_Y + MAX_DRAG * sin(angle);
      d  = MAX_DRAG;
    }

    velocity = d;
    aimX     = ax;
    aimY     = ay;
  }

  void drawAimUI() {
    float mx = muzzleX(), my = muzzleY();
    float p  = velocity / MAX_DRAG;

    pushStyle();
    stroke(ACCENT, 70 + 110 * p);
    strokeWeight(1.6f);
    line(mx, my, aimX, aimY);

    noStroke();
    fill(ACCENT, 46);
    circle(aimX, aimY, ballRadius * 2 + 10);
    fill(0xFF0B1B2A);
    stroke(ACCENT, 230);
    strokeWeight(1.6f);
    circle(aimX, aimY, ballRadius * 2);
    popStyle();
  }

  void drawTrajectory() {
    pushStyle();
    noStroke();
    float vx = velocity * cos(angle);
    float vy = velocity * sin(angle);
    int n = 34;
    for (int i = 1; i <= n; i++) {
      float t  = i * 0.32f;
      float px = CANNON_X - vx * t;
      float py = GRAVITY * t * t - vy * t + CANNON_Y;
      if (py > TARGET_ROW_Y + 8 || px > worldRight() + 20) break;
      float f = 1 - i / (float) n;
      fill(ACCENT, 20 + 150 * f);
      circle(px, py, 2 + 5.2f * f);
    }
    popStyle();
  }

  // -- Flight ---------------------------------------------------------------------
  // Fixed-step integration on the real clock. The flight always advances in
  // the same 0.1-unit samples it did before (exactly one per frame at 60 fps),
  // but the number of samples per frame follows real elapsed time. A device
  // stuck at 30 fps takes two samples per frame instead of playing in slow
  // motion, a 120 Hz display takes one every other frame instead of
  // fast-forwarding, and collision checks can never skip past the pad row.

  void updateProjectile() {
    flightAcc += 6.0f * dtSec;                            // 0.1 units per 60th of a second
    int guard = 0;
    while (isInFlight && flightAcc >= 0.1f && guard++ < 8) {
      flightAcc -= 0.1f;
      stepFlight();
    }
    if (flightAcc >= 0.1f) flightAcc = 0;                 // shed backlog after a huge hitch

    if (isInFlight) {
      float vx = velocity * cos(angle);
      float vy = velocity * sin(angle);
      drawBall(CANNON_X - vx * flightTime,
               GRAVITY * flightTime * flightTime - vy * flightTime + CANNON_Y);
    }
  }

  void stepFlight() {
    float t  = flightTime;
    float vx = velocity * cos(angle);
    float vy = velocity * sin(angle);
    float px = CANNON_X - vx * t;
    float py = GRAVITY * t * t - vy * t + CANNON_Y;

    spawnTrail(px, py, ballRadius * 0.9f);
    flightTime += 0.1f;

    // Complete miss: fell past the bottom of the screen
    if (py > worldBottom() + ballRadius) {
      endFlight();
      triggerGameOver();
      return;
    }

    // Weak lob that dropped back onto the cannon platform
    if (t > 0.5f && px <= 208 && py >= PLATFORM_TOP - ballRadius) {
      endFlight();
      spawnBurst(px, PLATFORM_TOP - 2, CORAL, 18, 2.6f);
      triggerGameOver();
      return;
    }

    // Reached the pad row
    if (py >= TARGET_ROW_Y - ballRadius && px >= TARGET_X && px <= TARGET_RIGHT) {
      endFlight();
      float cellW = TARGET_W / targetCount;
      int   cell  = constrain((int) ((px - TARGET_X) / cellW), 0, targetCount - 1);
      if (cell == targetIndex) {
        score++;
        sfxHit(score);
        scorePop  = 1;
        padFlash  = 1;
        padFlashX = TARGET_X + cell * cellW;
        padFlashW = cellW;
        spawnBurst(px, TARGET_ROW_Y - 4, ACCENT, 26, 3.4f);
        spawnRing(px, TARGET_ROW_Y - 2, ACCENT);
        spawnScoreFloat(px, TARGET_ROW_Y - 26);
        nextRound();
      } else {
        spawnBurst(px, TARGET_ROW_Y - 4, CORAL, 22, 3.0f);
        triggerGameOver();
      }
    }
  }

  // -- Targets --------------------------------------------------------------------

  void drawTargets() {
    float cellW = TARGET_W / targetCount;
    float gap   = min(7, cellW * 0.14f);

    pushStyle();
    rectMode(CORNER);
    for (int i = 0; i < targetCount; i++) {
      float x  = TARGET_X + i * cellW;
      float px = x + gap / 2;
      float pw = cellW - gap;

      if (i == targetIndex && !isGameOver) {
        float pu = 0.5f + 0.5f * sin(tSec() * 3.2f);
        drawLightColumn(px + pw / 2, TARGET_ROW_Y, pw * 0.72f, 170, 16 + 12 * pu);
        noStroke();
        fill(ACCENT, 30);
        rect(px - 3, TARGET_ROW_Y - 3, pw + 6, TARGET_H + 6, 8);
        fill(ACCENT, 70 + 50 * pu);
        stroke(ACCENT, 235);
        strokeWeight(1.4f);
        rect(px, TARGET_ROW_Y, pw, TARGET_H, 5);
      } else {
        fill(PANEL_LINE, 26);
        stroke(PANEL_LINE, 85);
        strokeWeight(1);
        rect(px, TARGET_ROW_Y, pw, TARGET_H, 5);
      }
    }

    if (padFlash > 0.01f) {
      noStroke();
      fill(255, 190 * padFlash);
      rect(padFlashX + gap / 2, TARGET_ROW_Y, padFlashW - gap, TARGET_H, 5);
      padFlash = max(0, padFlash - 0.05f * nf);
    }
    popStyle();
  }

  void drawLightColumn(float cx, float bottomY, float w, float h, float maxAlpha) {
    pushStyle();
    rectMode(CORNER);
    noStroke();
    int slices = qColumnSlices();
    for (int i = 0; i < slices; i++) {
      float f = i / (float) slices;             // 0 at pad, 1 at top
      fill(ACCENT, maxAlpha * (1 - f) * (1 - f));
      float sw = w * (1 - f * 0.35f);
      rect(cx - sw / 2, bottomY - (i + 1) * (h / (float) slices), sw, h / (float) slices + 1);
    }
    popStyle();
  }

  // -- HUD ------------------------------------------------------------------------

  void drawHUD() {
    pushStyle();

    textFont(fontRegular, 11);
    fill(INK_FAINT);
    trackedTextL("SCORE", 36, 40, 3);
    trackedTextR("BEST", 924, 40, 3);

    scorePop = max(0, scorePop - 0.05f * nf);
    float s = 1 + 0.4f * easeOutCubic(scorePop);
    pushMatrix();
    translate(37, 72);
    scale(s);
    textAlign(LEFT, CENTER);
    textFont(fontBold, 34);
    fill(INK);
    text(score, 0, 0);
    popMatrix();

    textAlign(RIGHT, CENTER);
    textFont(fontBold, 34);
    fill(INK_DIM);
    text(highScore, 924, 72);

    popStyle();
  }

  void drawReadouts() {
    pushStyle();
    textFont(fontRegular, 10);

    if (isAiming || isInFlight) {
      int deg = round(-degrees(angle - PI));
      int pct = round(velocity / MAX_DRAG * 100);
      fill(INK_DIM, isAiming ? 235 : 130);
      trackedTextL("ANGLE " + deg + "°    POWER " + pct + "%", 36, 584, 2.5f);
    } else if (!isGameOver) {
      float pu = 0.5f + 0.5f * sin(tSec() * 2.4f);
      fill(INK_FAINT, 150 + 70 * pu);
      trackedTextL("PULL THE GLOWING BALL TO AIM · RELEASE TO FIRE", 36, 584, 2.5f);
    }

    fill(INK_FAINT, 110);
    trackedTextR("BACK · MENU", 924, 584, 2.5f);
    popStyle();
  }

  // -- Game-over overlay ------------------------------------------------------------

  void drawGameOverOverlay() {
    overlayT = lerp(overlayT, 1, expK(0.14f));
    float e = easeOutCubic(overlayT);

    pushStyle();
    rectMode(CORNER);
    noStroke();
    fill(SKY_TOP, 205 * e);
    rect(worldLeft(), worldTop(), worldW, worldH);
    popStyle();

    float cy = centreY + 16 * (1 - e);
    drawPanel(centreX, cy, 430, 302, 24, e);

    pushStyle();
    textFont(fontBold, 15);
    fill(isNewRecord ? GOLD : CORAL, 255 * e);
    trackedTextC(isNewRecord ? "NEW RECORD" : "GAME OVER", centreX, cy - 94, 5);

    textAlign(CENTER, CENTER);
    textFont(fontBold, 88);
    fill(INK, 255 * e);
    text(score, centreX, cy - 24);

    textFont(fontRegular, 11.5f);
    fill(INK_FAINT, 255 * e);
    trackedTextC("BEST  " + highScore, centreX, cy + 44, 3);
    popStyle();

    btnAgain.y    = cy + 96;
    btnMenuOver.y = cy + 96;
    btnAgain.render(overlayT > 0.5f);
    btnMenuOver.render(overlayT > 0.5f);

    updateParticles();   // record confetti renders above the dim layer
  }

  // ===================================================================================
  // Menu
  // ===================================================================================

  UIButton[] menuBtns;
  UIButton btnAgain, btnMenuOver, btnGithub;

  void initUi() {
    menuBtns = new UIButton[] {
      new UIButton("PLAY",        centreX, 288, 250, 46, true),
      new UIButton("SETTINGS",    centreX, 348, 250, 46, false),
      new UIButton("HOW TO PLAY", centreX, 408, 250, 46, false),
      new UIButton("CREDITS",     centreX, 468, 250, 46, false),
      new UIButton("EXIT",        centreX, 528, 250, 46, false),
    };
    btnAgain    = new UIButton("PLAY AGAIN", centreX - 67, 0, 180, 46, true);
    btnMenuOver = new UIButton("MENU",       centreX + 97, 0, 120, 46, false);
    btnGithub   = new UIButton("GITHUB",     centreX, 0, 150, 42, false);

    icoClose      = new IconBtn(714, 140, ICON_CLOSE);
    icoSizeMinus  = new IconBtn(566, 232, ICON_MINUS);
    icoSizePlus   = new IconBtn(664, 232, ICON_PLUS);
    icoTgtsMinus  = new IconBtn(566, 292, ICON_MINUS);
    icoTgtsPlus   = new IconBtn(664, 292, ICON_PLUS);
    tglGuide      = new UIToggle(637, 352);
    tglSound      = new UIToggle(637, 412);
    sldVolume     = new UISlider(520, 472, 190);
  }

  void drawMenu() {
    drawBackground();
    drawMenuLogo();
    drawMenuButtons();
    drawMenuFooter();
  }

  void drawMenuLogo() {
    pushStyle();

    glowCircle(centreX, 118, 30, ACCENT, 40);
    if (shapeLogo != null) {
      shapeMode(CENTER);
      noStroke();
      fill(ACCENT);
      shape(shapeLogo, centreX, 118, 70, 56.4f);
    } else {
      // The glyph failed to load: a plain crest keeps the menu whole.
      noStroke();
      fill(ACCENT);
      circle(centreX, 118, 44);
    }

    float tr = 10;
    textFont(fontBold, 46);
    float w1 = trackedWidth("CANNON", tr);
    float w2 = trackedWidth("CRAZE", tr);
    float gp = 24;
    float x0 = centreX - (w1 + gp + w2) / 2;
    fill(INK);
    trackedTextL("CANNON", x0, 182, tr);
    fill(ACCENT);
    trackedTextL("CRAZE", x0 + w1 + gp, 182, tr);

    textFont(fontRegular, 11);
    fill(INK_FAINT);
    trackedTextC("PULL  ·  AIM  ·  RELEASE", centreX, 226, 4);

    popStyle();
  }

  void drawMenuButtons() {
    boolean interactive = (modalId == MODAL_NONE) && fadeT < 0.5f;
    for (UIButton b : menuBtns) b.render(interactive);
  }

  void drawMenuFooter() {
    pushStyle();
    textFont(fontRegular, 10.5f);
    fill(INK_FAINT);
    trackedTextL("BEST  " + highScore, 36, 574, 3);
    trackedTextR("ANAS UDDIN", 924, 574, 3);
    popStyle();
  }

  void handleMenuClick() {
    if      (menuBtns[0].contains(vmx, vmy)) { sfxClick(); startGame(); }
    else if (menuBtns[1].contains(vmx, vmy)) { sfxClick(); openModal(MODAL_SETTINGS); }
    else if (menuBtns[2].contains(vmx, vmy)) { sfxClick(); openModal(MODAL_HELP); }
    else if (menuBtns[3].contains(vmx, vmy)) { sfxClick(); openModal(MODAL_CREDITS); }
    else if (menuBtns[4].contains(vmx, vmy)) exitToSystem();
  }

  // ===================================================================================
  // Ui: buttons, modal windows, settings widgets
  // ===================================================================================

  static final int ICON_MINUS = 0;
  static final int ICON_PLUS  = 1;
  static final int ICON_CLOSE = 2;

  static final float CARD_X = 480, CARD_Y = 300, CARD_W = 540, CARD_R = 22;

  float modalHeight() {
    return (modalId == MODAL_SETTINGS) ? 500 : 392;
  }

  IconBtn  icoClose, icoSizeMinus, icoSizePlus, icoTgtsMinus, icoTgtsPlus;
  UIToggle tglGuide, tglSound;
  UISlider sldVolume;

  class UIButton {
    float x, y, w, h;
    String label;
    boolean primary;
    boolean enabled = true;
    float hov = 0;

    UIButton(String label, float x, float y, float w, float h, boolean primary) {
      this.label   = label;
      this.x = x;  this.y = y;  this.w = w;  this.h = h;
      this.primary = primary;
    }

    boolean contains(float mx, float my) {
      return enabled && abs(mx - x) <= w / 2 && abs(my - y) <= h / 2;
    }

    void render(boolean interactive) {
      boolean hot = interactive && contains(vmx, vmy) && mousePressed;
      hov = lerp(hov, hot ? 1 : 0, expK(0.22f));

      pushStyle();
      rectMode(CENTER);
      float r = h / 2;

      if (primary) {
        if (hov > 0.02f) {
          noStroke();
          for (int i = 3; i >= 1; i--) {
            fill(ACCENT, 22 * hov / i);
            rect(x, y, w + i * 7, h + i * 7, r + i * 4);
          }
        }
        noStroke();
        fill(lerpColor(ACCENT, ACCENT_SOFT, 0.45f * hov));
        rect(x, y, w, h, r);
        fill(BTN_TEXT_DARK);
        textFont(fontBold, 13);
        trackedTextC(label, x, y - 1, 2.6f);
      } else {
        stroke(lerpColor(PANEL_LINE, ACCENT, hov), 95 + 130 * hov);
        strokeWeight(1.2f);
        fill(ACCENT, 16 * hov);
        rect(x, y, w, h, r);
        fill(lerpColor(0xFFC7CCE8, ACCENT_SOFT, hov));
        textFont(fontBold, 12.5f);
        trackedTextC(label, x, y - 1, 2.6f);
      }
      popStyle();
    }
  }

  class IconBtn {
    float x, y;
    int   kind;
    float hov = 0;
    boolean enabled = true;

    IconBtn(float x, float y, int kind) {
      this.x = x;  this.y = y;  this.kind = kind;
    }

    boolean contains(float mx, float my) {
      return enabled && dist(mx, my, x, y) <= 24;   // a touch larger for fingers
    }

    void render(boolean interactive, float alphaMul) {
      boolean hot = interactive && enabled && contains(vmx, vmy) && mousePressed;
      hov = lerp(hov, hot ? 1 : 0, expK(0.25f));

      int hi = (kind == ICON_CLOSE) ? CORAL : ACCENT;
      float dimA = enabled ? 1 : 0.32f;

      pushStyle();
      stroke(lerpColor(PANEL_LINE, hi, hov), 100 * dimA * alphaMul + 120 * hov);
      strokeWeight(1.2f);
      fill(hi, 16 * hov);
      circle(x, y, 34);

      stroke(lerpColor(INK_DIM, hi, hov), 255 * dimA * alphaMul);
      strokeWeight(1.6f);
      if (kind == ICON_MINUS) {
        line(x - 5.5f, y, x + 5.5f, y);
      } else if (kind == ICON_PLUS) {
        line(x - 5.5f, y, x + 5.5f, y);
        line(x, y - 5.5f, x, y + 5.5f);
      } else {
        line(x - 5, y - 5, x + 5, y + 5);
        line(x - 5, y + 5, x + 5, y - 5);
      }
      popStyle();
    }
  }

  class UIToggle {
    float x, y;          // centre
    boolean on = true;
    float anim = 1;

    UIToggle(float x, float y) {
      this.x = x;  this.y = y;
    }

    boolean contains(float mx, float my) {
      return abs(mx - x) <= 30 && abs(my - y) <= 17;
    }

    void render(boolean interactive, float alphaMul) {
      anim = lerp(anim, on ? 1 : 0, expK(0.25f));

      pushStyle();
      rectMode(CENTER);
      noStroke();
      fill(lerpColor(0xFF232349, ACCENT_DEEP, anim), 255 * alphaMul);
      rect(x, y, 52, 28, 14);
      if (anim > 0.05f) {
        noFill();
        stroke(ACCENT, 90 * anim * alphaMul);
        strokeWeight(1.2f);
        rect(x, y, 52, 28, 14);
      }
      noStroke();
      fill(lerpColor(INK_DIM, INK, anim), 255 * alphaMul);
      circle(x + lerp(-12, 12, anim), y, 20);
      popStyle();
    }
  }

  // A draggable volume slider; a soft tick sounds at every five percent step
  // so the loudness can be judged while it is being set.
  class UISlider {
    float x, y, w;       // left end of the track, centre line, track width
    boolean dragging = false;
    float hov = 0;

    UISlider(float x, float y, float w) {
      this.x = x;  this.y = y;  this.w = w;
    }

    boolean contains(float mx, float my) {
      return mx >= x - 12 && mx <= x + w + 12 && abs(my - y) <= 20;
    }

    void setFromMouse(float mx) {
      float v = constrain((mx - x) / w, 0, 1);
      int oldStep = round(soundVolume * 20);
      soundVolume = v;
      if (round(v * 20) != oldStep) sfxTick();
    }

    void render(boolean interactive, float alphaMul, boolean enabled) {
      boolean hot = interactive && enabled && dragging;
      hov = lerp(hov, hot ? 1 : 0, expK(0.25f));

      float dimA = enabled ? 1 : 0.32f;
      float kx   = x + soundVolume * w;

      pushStyle();
      stroke(PANEL_LINE, 80 * dimA * alphaMul);
      strokeWeight(4);
      line(x, y, x + w, y);
      if (kx > x + 0.5f) {
        stroke(ACCENT, (150 + 70 * hov) * dimA * alphaMul);
        line(x, y, kx, y);
      }

      noStroke();
      if (hov > 0.02f && enabled) {
        fill(ACCENT, 36 * hov * alphaMul);
        circle(kx, y, 34);
      }
      fill(lerpColor(INK_DIM, INK, enabled ? 0.65f + 0.35f * hov : 0), 255 * dimA * alphaMul);
      circle(kx, y, 18);
      noFill();
      stroke(ACCENT, (110 + 130 * hov) * dimA * alphaMul);
      strokeWeight(1.2f);
      circle(kx, y, 18);

      fill(INK_FAINT, 235 * dimA * alphaMul);
      textFont(fontRegular, 9.5f);
      textAlign(CENTER, CENTER);
      text(round(soundVolume * 100) + "%", kx, y + 21);
      popStyle();
    }
  }

  // -- Modal windows --------------------------------------------------------------------

  void openModal(int m) {
    modalId = m;
    modalT  = 0;
  }

  void closeModal() {
    if (modalId == MODAL_NONE) return;
    if (modalId == MODAL_SETTINGS) {
      if (sldVolume != null) sldVolume.dragging = false;
      savePersistent();
    }
    modalId = MODAL_NONE;
    sfxClick();
  }

  void drawModal() {
    modalT = lerp(modalT, 1, expK(0.18f));
    float e = easeOutCubic(modalT);
    float cardH = modalHeight();

    pushStyle();
    rectMode(CORNER);
    noStroke();
    fill(SKY_TOP, 178 * e);
    rect(worldLeft(), worldTop(), worldW, worldH);
    popStyle();

    float cy      = CARD_Y + 16 * (1 - e);
    float cardTop = cy - cardH / 2;
    drawPanel(CARD_X, cy, CARD_W, cardH, CARD_R, e);

    if      (modalId == MODAL_SETTINGS) drawSettingsModal(cardTop, e);
    else if (modalId == MODAL_HELP)     drawHelpModal(cardTop, e);
    else                                drawCreditsModal(cardTop, e);

    icoClose.x = CARD_X + CARD_W / 2 - 36;
    icoClose.y = cardTop + 36;
    icoClose.render(modalT > 0.5f, e);
  }

  void drawModalTitle(String title, float cardTop, float e) {
    pushStyle();
    textFont(fontBold, 15);
    fill(INK, 255 * e);
    trackedTextC(title, CARD_X, cardTop + 52, 5);
    stroke(PANEL_LINE, 55 * e);
    strokeWeight(1);
    line(CARD_X - 90, cardTop + 78, CARD_X + 90, cardTop + 78);
    popStyle();
  }

  // -- Settings ---------------------------------------------------------------------------

  void drawSettingsModal(float cardTop, float e) {
    drawModalTitle("SETTINGS", cardTop, e);

    float rowSize = cardTop + 124;
    float rowTgts = cardTop + 182;
    float rowGde  = cardTop + 240;
    float rowSnd  = cardTop + 298;
    float rowVol  = cardTop + 356;
    float labelX  = CARD_X - CARD_W / 2 + 62;

    pushStyle();
    textFont(fontRegular, 12.5f);
    fill(INK_DIM, 255 * e);
    trackedTextL("CANNONBALL SIZE",  labelX, rowSize, 2);
    trackedTextL("TARGETS",          labelX, rowTgts, 2);
    trackedTextL("TRAJECTORY GUIDE", labelX, rowGde, 2);
    trackedTextL("SOUND",            labelX, rowSnd, 2);
    fill(INK_DIM, (soundOn ? 255 : 110) * e);
    trackedTextL("VOLUME",           labelX, rowVol, 2);

    textAlign(CENTER, CENTER);
    textFont(fontBold, 20);
    fill(INK, 255 * e);
    text((int) ballRadius, 615, rowSize - 1);
    text(targetCount,      615, rowTgts - 1);

    textFont(fontRegular, 9.5f);
    fill(INK_FAINT, 220 * e);
    trackedTextC("CHANGES SAVE AUTOMATICALLY", CARD_X, cardTop + 446, 3);
    popStyle();

    icoSizeMinus.y = rowSize;  icoSizePlus.y = rowSize;
    icoTgtsMinus.y = rowTgts;  icoTgtsPlus.y = rowTgts;
    tglGuide.y     = rowGde;
    tglSound.y     = rowSnd;
    sldVolume.y    = rowVol;
    tglGuide.on    = !guidelineHidden;
    tglSound.on    = soundOn;

    icoSizeMinus.enabled = ballRadius  > BALL_RADIUS_MIN;
    icoSizePlus.enabled  = ballRadius  < BALL_RADIUS_MAX;
    icoTgtsMinus.enabled = targetCount > TARGETS_MIN;
    icoTgtsPlus.enabled  = targetCount < TARGETS_MAX;

    boolean live = modalT > 0.5f;
    icoSizeMinus.render(live, e);
    icoSizePlus.render(live, e);
    icoTgtsMinus.render(live, e);
    icoTgtsPlus.render(live, e);
    tglGuide.render(live, e);
    tglSound.render(live, e);
    sldVolume.render(live, e, soundOn);
  }

  // -- Help --------------------------------------------------------------------------------

  final String[] HELP_STEPS = {
    "Touch and hold the glowing cannonball.",
    "Pull back. Distance sets power, direction sets angle.",
    "Let go to fire the shot.",
    "Land on the lit pad to score and keep the run alive.",
    "One miss ends the run. Beat your best score."
  };

  void drawHelpModal(float cardTop, float e) {
    drawModalTitle("HOW TO PLAY", cardTop, e);

    pushStyle();
    for (int i = 0; i < HELP_STEPS.length; i++) {
      float y = cardTop + 124 + i * 46;
      textFont(fontBold, 14);
      fill(ACCENT, 255 * e);
      trackedTextL("0" + (i + 1), CARD_X - CARD_W / 2 + 62, y, 1.5f);
      textAlign(LEFT, CENTER);
      textFont(fontRegular, 13);
      fill(0xFFC9CFEA, 255 * e);
      text(HELP_STEPS[i], CARD_X - CARD_W / 2 + 104, y - 1);
    }
    popStyle();
  }

  // -- Credits -----------------------------------------------------------------------------

  void drawCreditsModal(float cardTop, float e) {
    drawModalTitle("CREDITS", cardTop, e);

    pushStyle();
    textAlign(CENTER, CENTER);
    textFont(fontScript, 46);
    fill(ACCENT_SOFT, 255 * e);
    text("Anas Uddin", CARD_X, cardTop + 160);

    textFont(fontRegular, 12);
    fill(INK_DIM, 255 * e);
    trackedTextC("DESIGNED  &  DEVELOPED  WITH  CARE", CARD_X, cardTop + 226, 2.5f);
    popStyle();

    btnGithub.y = cardTop + 300;
    btnGithub.render(modalT > 0.5f);
  }

  // -- Modal input ---------------------------------------------------------------------------

  void handleModalClick() {
    // Touch outside the card dismisses it
    if (abs(vmx - CARD_X) > CARD_W / 2 + 4 || abs(vmy - CARD_Y) > modalHeight() / 2 + 20) {
      closeModal();
      return;
    }

    if (icoClose.contains(vmx, vmy)) {
      closeModal();
      return;
    }

    if (modalId == MODAL_SETTINGS) {
      if      (icoSizeMinus.contains(vmx, vmy)) { ballRadius  = max(ballRadius - 1, BALL_RADIUS_MIN);  sfxClick(); }
      else if (icoSizePlus.contains(vmx, vmy))  { ballRadius  = min(ballRadius + 1, BALL_RADIUS_MAX);  sfxClick(); }
      else if (icoTgtsMinus.contains(vmx, vmy)) { targetCount = max(targetCount - 1, TARGETS_MIN);     sfxClick(); }
      else if (icoTgtsPlus.contains(vmx, vmy))  { targetCount = min(targetCount + 1, TARGETS_MAX);     sfxClick(); }
      else if (tglGuide.contains(vmx, vmy))     { guidelineHidden = !guidelineHidden;                  sfxToggle(); }
      else if (tglSound.contains(vmx, vmy))     { soundOn = !soundOn;                                  sfxToggle(); }
      else if (soundOn && sldVolume.contains(vmx, vmy)) {
        sldVolume.dragging = true;
        sldVolume.setFromMouse(vmx);
        return;   // saved on release, once the drag settles
      }
      else return;
      savePersistent();
    } else if (modalId == MODAL_CREDITS) {
      if (btnGithub.contains(vmx, vmy)) {
        sfxClick();
        link("https://github.com/theanasuddin");
      }
    }
  }

  // ===================================================================================
  // Particles: sparks, trails, shockwave rings, floating score text
  // ===================================================================================

  static final int P_SPARK = 0;
  static final int P_TRAIL = 1;
  static final int P_RING  = 2;
  static final int P_TEXT  = 3;

  ArrayList<Particle> particles;

  class Particle {
    int    kind;
    float  x, y, vx, vy;
    float  age = 0, life, size;
    int    col;
    String txt;

    Particle(int kind, float x, float y, float vx, float vy, float life, float size, int col) {
      this.kind = kind;
      this.x = x;  this.y = y;  this.vx = vx;  this.vy = vy;
      this.life = life;  this.size = size;  this.col = col;
    }
  }

  void initParticles() {
    particles = new ArrayList<Particle>();
  }

  void clearParticles() {
    particles.clear();
  }

  void spawnBurst(float x, float y, int c, int n, float speed) {
    int count = max(1, round(n * qBurstFrac()));
    for (int i = 0; i < count; i++) {
      float a = random(TWO_PI);
      float s = random(0.4f, 1.0f) * speed;
      particles.add(new Particle(P_SPARK, x, y, cos(a) * s, sin(a) * s - 1,
                                 random(0.4f, 0.9f), random(2, 4.5f), c));
    }
  }

  void spawnRecordBurst(float x, float y) {
    int count = round(46 * qBurstFrac());
    for (int i = 0; i < count; i++) {
      float a = random(TWO_PI);
      float s = random(1.2f, 4.6f);
      int   c = (i % 2 == 0) ? GOLD : ACCENT;
      particles.add(new Particle(P_SPARK, x, y, cos(a) * s, sin(a) * s - 2,
                                 random(0.7f, 1.4f), random(2.5f, 5), c));
    }
  }

  int trailTick = 0;

  void spawnTrail(float x, float y, float size) {
    if (++trailTick % qTrailEvery() != 0) return;   // thinner comet tail on LOW
    particles.add(new Particle(P_TRAIL, x, y, 0, 0, 0.45f, size, ACCENT));
  }

  void spawnRing(float x, float y, int c) {
    particles.add(new Particle(P_RING, x, y, 0, 0, 0.55f, 78, c));
  }

  void spawnScoreFloat(float x, float y) {
    Particle p = new Particle(P_TEXT, x, y, 0, -0.9f, 0.9f, 15, ACCENT_SOFT);
    p.txt = "+1";
    particles.add(p);
  }

  void updateParticles() {
    pushStyle();
    for (int i = particles.size() - 1; i >= 0; i--) {
      Particle p = particles.get(i);
      p.age += dtSec;
      float u = p.age / p.life;
      if (u >= 1) {
        particles.remove(i);
        continue;
      }

      if (p.kind == P_SPARK) {
        p.vy += 0.13f * nf;
        p.x  += p.vx * nf;
        p.y  += p.vy * nf;
        noStroke();
        fill(p.col, 235 * (1 - u));
        circle(p.x, p.y, p.size * (1 - u * 0.55f));
      } else if (p.kind == P_TRAIL) {
        noStroke();
        fill(p.col, 80 * (1 - u));
        circle(p.x, p.y, p.size * 2 * (1 - u));
      } else if (p.kind == P_RING) {
        noFill();
        stroke(p.col, 210 * (1 - u));
        strokeWeight(2.2f * (1 - u) + 0.4f);
        circle(p.x, p.y, p.size * easeOutCubic(u));
      } else {
        p.y += p.vy * nf;
        noStroke();
        textAlign(CENTER, CENTER);
        textFont(fontBold, p.size);
        fill(p.col, 255 * (1 - u));
        text(p.txt, p.x, p.y);
      }
    }
    popStyle();
  }

  // ===================================================================================
  // Sound: procedurally synthesized effects through the AudioTrack mixer
  // ===================================================================================
  // Identical synthesis to the desktop build: every sound is generated at
  // startup as 16-bit 44.1 kHz PCM. There are no audio asset files.

  static final int SND_RATE = 44100;

  SoundEngine sndEngine;

  short[]   sndLaunch, sndGameOver, sndRecord, sndClick, sndToggle, sndGrab, sndTick;
  short[][] sndHit = new short[8][];   // score chime ladder: pitch rises with the run

  void initSound() {
    buildAllSounds();
    sndEngine = new SoundEngine();
  }

  void playSound(short[] samples) {
    if (sndEngine == null || !soundOn) return;
    // Perceptual volume: amplitude = volume squared
    sndEngine.play(samples, soundVolume * soundVolume);
  }

  void sfxLaunch()          { playSound(sndLaunch); }
  void sfxHit(int runScore) { playSound(sndHit[constrain(runScore - 1, 0, sndHit.length - 1)]); }
  void sfxGameOver()        { playSound(sndGameOver); }
  void sfxRecord()          { playSound(sndRecord); }
  void sfxClick()           { playSound(sndClick); }
  void sfxToggle()          { playSound(sndToggle); }
  void sfxGrab()            { playSound(sndGrab); }
  void sfxTick()            { playSound(sndTick); }

  void buildAllSounds() {
    sndLaunch   = buildLaunch();
    sndGameOver = buildGameOver();
    sndRecord   = buildRecord();
    sndClick    = buildBlip(1850, 0.055f, 90,  0.42f);
    sndToggle   = buildBlip(1250, 0.060f, 70,  0.42f);
    sndTick     = buildBlip(2300, 0.030f, 160, 0.30f);
    sndGrab     = buildGrab();

    // Major pentatonic ladder starting at C5: every hit in a run sounds one
    // step brighter than the last, capping at the top of the ladder.
    float[] ladder = { 523.25f, 587.33f, 659.26f, 783.99f, 880.00f, 1046.50f, 1174.66f, 1318.51f };
    for (int i = 0; i < ladder.length; i++) sndHit[i] = buildChime(ladder[i]);
  }

  short[] buildLaunch() {
    int n = (int) (SND_RATE * 0.32f);
    float[] b = new float[n];
    float phase = 0, lp = 0;
    for (int i = 0; i < n; i++) {
      float t = i / (float) SND_RATE;
      float u = i / (float) n;
      float f = lerp(155, 42, sqrt(u));
      phase += TWO_PI * f / SND_RATE;
      float body  = sin(phase) * exp(-t * 9);
      float noise = random(-1, 1) * exp(-t * 55);
      lp += (noise - lp) * 0.16f;
      b[i] = (float) Math.tanh((body * 0.95f + lp * 1.5f) * 1.7f) * 0.95f;
    }
    return toPcm(b, 0.95f);
  }

  short[] buildChime(float f) {
    int n = (int) (SND_RATE * 0.55f);
    float[] b = new float[n];
    for (int i = 0; i < n; i++) {
      float t = i / (float) SND_RATE;
      float x = sin(TWO_PI * f * t)           * exp(-t * 6.5f)
              + sin(TWO_PI * f * 1.006f * t)  * exp(-t * 6.5f) * 0.30f
              + sin(TWO_PI * f * 2.002f * t)  * exp(-t * 9.0f) * 0.50f
              + sin(TWO_PI * f * 2.997f * t)  * exp(-t * 13 )  * 0.18f;
      b[i] = x * min(1, t / 0.002f) * 0.42f;
    }
    return toPcm(b, 0.9f);
  }

  short[] buildGameOver() {
    int n = (int) (SND_RATE * 0.6f);
    float[] b = new float[n];
    float phase = 0, lp = 0;
    for (int i = 0; i < n; i++) {
      float t = i / (float) SND_RATE;
      float u = i / (float) n;
      float f = lerp(196, 68, u * u * (3 - 2 * u));
      phase += TWO_PI * f / SND_RATE;
      float tone  = (sin(phase) + 0.35f * sin(phase * 2 + 0.6f)) * exp(-t * 5.5f);
      float noise = random(-1, 1) * exp(-t * 34);
      lp += (noise - lp) * 0.12f;
      b[i] = (float) Math.tanh((tone * 0.8f + lp * 1.1f) * 1.5f) * 0.9f;
    }
    return toPcm(b, 0.9f);
  }

  short[] buildRecord() {
    float[] notes  = { 523.25f, 659.26f, 783.99f, 1046.50f };
    float[] onsets = { 0.00f, 0.10f, 0.20f, 0.30f };
    int n = (int) (SND_RATE * 1.15f);
    float[] b = new float[n];
    for (int k = 0; k < notes.length; k++) {
      boolean last  = (k == notes.length - 1);
      float   decay = last ? 3.5f : 7.0f;
      float   gain  = last ? 0.42f : 0.32f;
      int start = (int) (onsets[k] * SND_RATE);
      for (int i = start; i < n; i++) {
        float t = (i - start) / (float) SND_RATE;
        float x = sin(TWO_PI * notes[k] * t)          * exp(-t * decay)
                + sin(TWO_PI * notes[k] * 2.003f * t) * exp(-t * (decay + 3)) * 0.45f;
        b[i] += x * min(1, t / 0.002f) * gain;
      }
    }
    return toPcm(b, 0.9f);
  }

  short[] buildBlip(float f, float dur, float decay, float gain) {
    int n = (int) (SND_RATE * dur);
    float[] b = new float[n];
    for (int i = 0; i < n; i++) {
      float t = i / (float) SND_RATE;
      float x = sin(TWO_PI * f * t) * exp(-t * decay)
              + random(-1, 1) * exp(-t * 420) * 0.20f;
      b[i] = x * min(1, t / 0.001f) * gain;
    }
    return toPcm(b, 0.9f);
  }

  short[] buildGrab() {
    int n = (int) (SND_RATE * 0.09f);
    float[] b = new float[n];
    float phase = 0;
    for (int i = 0; i < n; i++) {
      float t = i / (float) SND_RATE;
      float u = i / (float) n;
      phase += TWO_PI * lerp(290, 430, u) / SND_RATE;
      b[i] = sin(phase) * exp(-t * 28) * min(1, t / 0.002f) * 0.30f;
    }
    return toPcm(b, 0.9f);
  }

  short[] toPcm(float[] b, float amp) {
    short[] out = new short[b.length];
    for (int i = 0; i < b.length; i++) {
      out[i] = (short) (constrain(b[i] * amp, -1, 1) * 32767);
    }
    return out;
  }

  // ===================================================================================
  // Persistence: SharedPreferences instead of the desktop's text files
  // ===================================================================================

  SharedPreferences prefs() {
    return getActivity().getSharedPreferences("cannoncraze", Context.MODE_PRIVATE);
  }

  void loadPersistent() {
    try {
      SharedPreferences p = prefs();
      highScore       = p.getInt("highScore", 0);
      targetCount     = constrain(p.getInt("targetCount", 10), TARGETS_MIN, TARGETS_MAX);
      guidelineHidden = p.getBoolean("guidelineHidden", false);
      ballRadius      = constrain(p.getInt("ballRadius", 12), BALL_RADIUS_MIN, BALL_RADIUS_MAX);
      soundOn         = p.getBoolean("soundOn", true);
      soundVolume     = constrain(p.getInt("volume", 80), 0, 100) / 100.0f;
    } catch (Exception e) {
      // keep defaults
    }
  }

  void savePersistent() {
    try {
      prefs().edit()
        .putInt("highScore", highScore)
        .putInt("targetCount", targetCount)
        .putBoolean("guidelineHidden", guidelineHidden)
        .putInt("ballRadius", (int) ballRadius)
        .putBoolean("soundOn", soundOn)
        .putInt("volume", round(soundVolume * 100))
        .apply();
    } catch (Exception e) {
      e.printStackTrace();
    }
  }
}
