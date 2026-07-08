// -- Cannon Craze -----------------------------------------------------------------
// A minimal neon-noir arcade cannon game.
// Pull the cannonball back to aim, release to fire, land on the lit pad.
//
// Tabs: Theme (design system) - Viewport (resizable window) - Background (scene)
//       Gameplay - Menu - Ui - Particles - Sound - Persistence

// -- Screens / flow ---------------------------------------------------------------

final int SCREEN_MENU = 0;
final int SCREEN_PLAY = 1;

final int MODAL_NONE     = 0;
final int MODAL_SETTINGS = 1;
final int MODAL_HELP     = 2;
final int MODAL_CREDITS  = 3;

int screenId = SCREEN_MENU;
int modalId  = MODAL_NONE;

// -- Gameplay constants -----------------------------------------------------------

final float CANNON_X     = 126;    // barrel pivot / launch origin
final float CANNON_Y     = 380;
final float PLATFORM_TOP = 392;
final float BARREL_LEN   = 46;
final float MAX_DRAG     = 160;    // px of pull == launch velocity
final float GRAVITY      = 16;

final int BALL_RADIUS_MIN = 5;
final int BALL_RADIUS_MAX = 15;

final float TARGET_X     = 220;
final float TARGET_W     = 660;
final float TARGET_RIGHT = TARGET_X + TARGET_W;
final float TARGET_ROW_Y = 552;
final float TARGET_H     = 16;
final int   TARGETS_MIN  = 5;
final int   TARGETS_MAX  = 15;

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
float   soundVolume     = 0.8;   // 0..1 master volume

// Ball / physics
float   angle      = 0;      // pull angle (ball dragged down-left of the pivot)
float   velocity   = 0;
float   flightTime = 0;
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

float   centreX, centreY;
boolean wantHand = false;    // any control hovered this frame gets a hand cursor

// -- Setup / draw -----------------------------------------------------------------

void setup() {
  // Initial window size == the virtual canvas (VIEW_W x VIEW_H). The custom
  // renderer is the stock JAVA2D pipeline plus a fix for a JDK race that used
  // to freeze the sketch during live window resizes.
  size(960, 600, "CannonCrazeGraphics");
  pixelDensity(displayDensity());
  surface.setTitle("Cannon Craze");
  surface.setIcon(loadImage("icon.png"));

  centreX = VIEW_W / 2.0;
  centreY = VIEW_H / 2.0;

  loadTheme();
  initViewport();
  initUi();
  initParticles();

  highScore = loadHighScore("high_score.txt");
  loadSettings("settings.txt");
  initSound();
}

void draw() {
  updateViewport();
  wantHand = false;

  beginViewport();

  if (screenId == SCREEN_MENU) drawMenu();
  else                         drawGameplay();

  if (modalId != MODAL_NONE) drawModal();

  if (fadeT > 0.004) {
    fadeT = lerp(fadeT, 0, 0.16);
    pushStyle();
    rectMode(CORNER);
    noStroke();
    fill(SKY_TOP, 255 * fadeT);
    rect(worldLeft(), worldTop(), worldW, worldH);
    popStyle();
  }

  endViewport();

  cursor(wantHand ? HAND : ARROW);
}

float tSec() {
  return millis() / 1000.0;
}

// -- Input ------------------------------------------------------------------------

void mousePressed() {
  if (mouseButton != LEFT) return;
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

void mouseDragged() {
  if (sldVolume != null && sldVolume.dragging) {
    syncCanvasMouse();
    sldVolume.setFromMouse(vmx);
  }
}

void mouseReleased() {
  if (sldVolume != null && sldVolume.dragging) {
    sldVolume.dragging = false;
    saveSettings("settings.txt");
    return;
  }
  if (!isAiming) return;
  isAiming = false;
  if (velocity > 4) launch();   // a tiny nudge cancels instead of firing
}

void keyPressed() {
  if (key != ESC) return;
  key = 0;                      // keep Processing from closing the window
  if      (modalId != MODAL_NONE)   closeModal();
  else if (screenId == SCREEN_PLAY) toMenu();
  else                              exit();
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
  isAiming   = false;
  isInFlight = false;

  int next = targetIndex;
  while (next == targetIndex && targetCount > 1) {
    next = int(random(targetCount));
  }
  targetIndex = max(0, next);
}

void launch() {
  isInFlight = true;
  flightTime = 0;
  recoilT    = 1;
  spawnBurst(muzzleX(), muzzleY(), ACCENT, 10, 2.2);
  sfxLaunch();
}

void endFlight() {
  isInFlight = false;
  flightTime = 0;
}

void triggerGameOver() {
  isGameOver  = true;
  overlayT    = 0;
  shakeT      = 1;
  isNewRecord = score > highScore;
  if (isNewRecord) {
    highScore = score;
    saveHighScore();
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
