// ── Constants ──────────────────────────────────────────────────────────────────

// Colors
final color COL_PRIMARY          = #080340;
final color COL_ACCENT           = #26ECE2;
final color COL_CLIFF            = #350528;
final color COL_GUIDE            = #3472C5;
final color COL_WIN_TEXT         = #468847;
final color COL_WINDOW_BG        = #9DDBF0;
final color COL_WINDOW_STROKE    = #FF7D5A;
final color COL_BTN_HOVER_STROKE = #FEAE0D;

// Cannon / ball
final float CANNON_X        = 108.5;
final float CANNON_Y        = 327.5;
final float GUIDE_LENGTH    = 55;
final float MAX_VELOCITY    = 150;
final int   BALL_RADIUS_MIN = 5;
final int   BALL_RADIUS_MAX = 15;

// Target area — fixed 550 px wide, x: 162.5 → 712.5
final float TARGET_X      = 162.5;
final float TARGET_W      = 550.0;
final float TARGET_RIGHT  = TARGET_X + TARGET_W;
final float TARGET_ROW_Y  = 521.5;
final float TARGET_H      = 24;
final int   TARGETS_MIN   = 5;
final int   TARGETS_MAX   = 15;

// Settings window widget positions (top-left of each 20×20 hit region)
final float CTRL_CLOSE_X  = 585;
final float CTRL_CLOSE_Y  = 159;
final float CTRL_LEFT_X   = 438;
final float CTRL_RIGHT_X  = 550;
final float CTRL_VALUE_X  = 499;
final float CTRL_SIZE_Y   = 215;
final float CTRL_TGTS_Y   = 247;
final float CTRL_CHK_X    = 494;
final float CTRL_CHK_Y    = 311;

// ── Assets ─────────────────────────────────────────────────────────────────────

PImage imgGameBg, imgMenuBg;
PImage imgClose, imgCloseHover;
PImage imgFlower;
PImage imgGithub, imgGithubHover;
PImage imgChecked, imgCheckedHover;
PImage imgUnchecked, imgUncheckedHover;
PImage imgLeftArrow, imgLeftArrowHover;
PImage imgRightArrow, imgRightArrowHover;

PFont  fontRegular, fontBold, fontScript;
PShape shapeCannon;

// ── Game state ─────────────────────────────────────────────────────────────────

int     score     = 0;
int     highScore = 0;
boolean isGameOver = false;
boolean isWin      = false;

// ── Ball / physics ─────────────────────────────────────────────────────────────

float   ballRadius = 12;   // 25 / 2 (integer division), mutated via settings
float   angle      = 0;
float   velocity   = 0;
float   flightTime = 0;
boolean isAiming   = false;
boolean isInFlight = false;

// ── Targets ────────────────────────────────────────────────────────────────────

int   targetCount = 10;
int   targetIndex = 0;
float targetX     = 0;   // left edge of the desired brick

// ── UI / screen state ──────────────────────────────────────────────────────────

boolean showMainMenu     = true;
boolean showSettings     = false;
boolean showInstructions = false;
boolean showCredits      = false;
boolean guidelineHidden  = false;

// Hover flags — main menu
boolean hoverPlay, hoverSettings, hoverHelp, hoverCredits, hoverExit;
// Hover flags — game-over screen
boolean hoverPlayAgain, hoverMainMenu;

float centreX, centreY;

// ── Setup / draw ───────────────────────────────────────────────────────────────

void setup() {
  size(740, 545);
  surface.setTitle("Cannon Craze");

  centreX = width  / 2.0;
  centreY = height / 2.0;

  PImage icon = loadImage("icon.png");
  surface.setIcon(icon);

  loadAssets();
  highScore = loadHighScore("high_score.txt");
  loadSettings("settings.txt");
}

void loadAssets() {
  imgGameBg         = loadImage("game_background.png");
  imgMenuBg         = loadImage("menu_background.jpg");
  imgClose          = loadImage("close_button.png");
  imgCloseHover     = loadImage("close_button_hover.png");
  imgFlower         = loadImage("flower.png");
  imgGithub         = loadImage("github.png");
  imgGithubHover    = loadImage("github_hover.png");
  imgChecked        = loadImage("checked_checkbox.png");
  imgCheckedHover   = loadImage("checked_checkbox_hover.png");
  imgUnchecked      = loadImage("unchecked_checkbox.png");
  imgUncheckedHover = loadImage("unchecked_checkbox_hover.png");
  imgLeftArrow      = loadImage("left_arrow.png");
  imgLeftArrowHover = loadImage("left_arrow_hover.png");
  imgRightArrow     = loadImage("right_arrow.png");
  imgRightArrowHover = loadImage("right_arrow_hover.png");

  fontRegular = createFont("Montserrat-Regular.otf", 192);
  fontBold    = createFont("Montserrat-Bold.otf",    192);
  fontScript  = createFont("Playlist-Script.otf",    192);

  shapeCannon = loadShape("logo.svg");
}

void draw() {
  if (showSettings) {
    image(imgMenuBg, 0, 0);
    drawSettingsWindow();
  } else if (showInstructions) {
    image(imgMenuBg, 0, 0);
    drawInstructionsWindow();
  } else if (showCredits) {
    image(imgMenuBg, 0, 0);
    drawCreditWindow();
  } else if (showMainMenu) {
    image(imgMenuBg, 0, 0);
    drawCannonLogo();
    drawMainMenuButtons();
  } else if (!isGameOver) {
    drawGameplay();
  } else {
    drawGameOverScreen();
  }
}

// ── Gameplay ───────────────────────────────────────────────────────────────────

void drawGameplay() {
  image(imgGameBg, 0, 0);

  drawCliff();
  drawHUD();
  targetX = drawTargets(targetIndex);

  if (isInFlight) {
    updateProjectile(flightTime);
    flightTime += 0.1;
  } else {
    drawCannonball(CANNON_X, CANNON_Y);
  }

  if (!guidelineHidden) drawAngleGuides();

  if (mousePressed && !isInFlight) {
    drawAimingBall();
  } else {
    isAiming = false;
  }

  updateGameplayCursor();
}

void drawCliff() {
  fill(COL_CLIFF);
  strokeWeight(1);
  stroke(COL_GUIDE);
  quad(-1, 324.5, CANNON_X, CANNON_Y, 130.5, height, -1, height);
}

void drawCannonball(float x, float y) {
  fill(COL_ACCENT);
  stroke(COL_PRIMARY);
  strokeWeight(1);
  ellipse(x, y, ballRadius * 2, ballRadius * 2);
}

float drawTargets(int desired) {
  float brickW  = TARGET_W / targetCount;
  float posX    = TARGET_X;
  float desiredX = 0;

  strokeWeight(1);
  rectMode(CORNER);
  for (int i = 0; i < targetCount; i++) {
    if (i == desired) {
      fill(COL_ACCENT);
      desiredX = posX;
    } else {
      fill(COL_CLIFF);
    }
    rect(posX, TARGET_ROW_Y, brickW, TARGET_H, 2);
    posX += brickW;
  }
  return desiredX;
}

void drawAngleGuides() {
  stroke(COL_GUIDE);
  strokeWeight(1);
  line(CANNON_X, CANNON_Y, CANNON_X + GUIDE_LENGTH, CANNON_Y);
  line(CANNON_X, CANNON_Y, CANNON_X, CANNON_Y - GUIDE_LENGTH);

  if (isAiming && !isInFlight) {
    strokeWeight(5);
    float ex = CANNON_X - GUIDE_LENGTH * cos(angle);
    float ey = CANNON_Y - GUIDE_LENGTH * sin(angle);
    line(CANNON_X, CANNON_Y, ex, ey);
  }
}

void drawAimingBall() {
  if (!isAiming) return;

  float ax = min(mouseX, CANNON_X - 0.01);
  float ay = max(mouseY, CANNON_Y + 0.01);

  angle = atan2(ay - CANNON_Y, ax - CANNON_X);
  if (dist(ax, ay, CANNON_X, CANNON_Y) >= MAX_VELOCITY) {
    ax = CANNON_X - 0.01 + MAX_VELOCITY * cos(angle);
    ay = CANNON_Y + 0.01 + MAX_VELOCITY * sin(angle);
    angle = atan2(ay - CANNON_Y, ax - CANNON_X);
  }

  fill(COL_ACCENT);
  stroke(COL_GUIDE);
  strokeWeight(1);
  ellipse(ax, ay, ballRadius * 2, ballRadius * 2);

  if (!guidelineHidden) {
    strokeWeight(5);
    line(ax, ay, CANNON_X, CANNON_Y);
  }

  velocity = min(dist(ax, ay, CANNON_X, CANNON_Y), MAX_VELOCITY);
}

void updateProjectile(float t) {
  float vx   = velocity * cos(angle);
  float vy   = velocity * sin(angle);
  float posX = CANNON_X - vx * t;
  float posY = 16 * pow(t, 2) - vy * t + CANNON_Y;

  drawCannonball(posX, posY);

  // Ball fell below screen outside the target zone — complete miss
  if (posY > height + ballRadius) {
    endFlight();
    triggerGameOver();
    return;
  }

  // Ball reached the target row
  if (posY >= TARGET_ROW_Y - ballRadius
      && posX >= TARGET_X - ballRadius
      && posX <= TARGET_RIGHT + ballRadius) {
    endFlight();
    float brickW = TARGET_W / targetCount;
    boolean hitDesired = posX >= targetX + ballRadius
                      && posX <= targetX + brickW - ballRadius;
    if (hitDesired) {
      score++;
      nextRound();
    } else {
      triggerGameOver();
    }
  }
}

void updateGameplayCursor() {
  boolean onBall = hitTestCircle(mouseX, mouseY, CANNON_X, CANNON_Y, ballRadius);
  cursor((isAiming || onBall) && !isInFlight ? HAND : ARROW);
}

// ── HUD ────────────────────────────────────────────────────────────────────────

void drawHUD() {
  fill(COL_GUIDE);
  textAlign(BASELINE);

  textSize(14);
  text("Velocity: " + String.format("%.2f", velocity),                     10, height - 26);
  text("Angle: "    + String.format("%.2f", angle == 0 ? angle : 180 - angle), 10, height - 11);

  textSize(21);
  text("High Score: " + highScore, 557.5, 57.5);
  text("Your Score: " + score,     557.5, 80.5);
}

// ── Game-over screen ───────────────────────────────────────────────────────────

void drawGameOverScreen() {
  image(imgMenuBg, 0, 0);

  rectMode(CENTER);
  strokeWeight(3);
  textAlign(CENTER, CENTER);
  textFont(fontRegular, 17);

  float resultY    = centreY - 106;
  float playAgainY = centreY;
  float mainMenuY  = centreY + 106;

  String resultText  = isWin ? "You Win!" : "You Lost!";
  color  resultColor = isWin ? color(COL_WIN_TEXT) : color(COL_CLIFF);

  fill(COL_ACCENT);
  stroke(COL_BTN_HOVER_STROKE);
  rect(centreX, resultY, 260, 57, 2);
  fill(resultColor);
  textSize(17);
  text("Your Score: " + score + ", High Score: " + highScore + "\n" + resultText, centreX, resultY);

  updateGameOverCursor();
  drawMenuButton(centreX, playAgainY, "Play Again", hoverPlayAgain);
  drawMenuButton(centreX, mainMenuY,  "Main Menu",  hoverMainMenu);
}

void updateGameOverCursor() {
  if (isMouseOver(centreX, centreY, 124, 57)) {
    cursor(HAND);
    hoverPlayAgain = true;
    hoverMainMenu  = false;
  } else if (isMouseOver(centreX, centreY + 106, 124, 57)) {
    cursor(HAND);
    hoverMainMenu  = true;
    hoverPlayAgain = false;
  } else {
    cursor(ARROW);
    hoverPlayAgain = false;
    hoverMainMenu  = false;
  }
}

// ── Main menu ──────────────────────────────────────────────────────────────────

void drawCannonLogo() {
  rectMode(CENTER);
  fill(COL_WINDOW_BG);
  stroke(COL_WINDOW_STROKE);
  strokeWeight(3);
  rect(centreX, centreY, 170, 213.67, 2);

  textFont(fontBold, 24);
  fill(COL_PRIMARY);
  textAlign(CENTER, CENTER);
  text("CANNON\nCRAZE", 370.5, 335);

  shapeMode(CENTER);
  noStroke();
  PShape logo = shapeCannon.getChild("Layer 1");
  logo.disableStyle();
  fill(COL_PRIMARY);
  shape(logo, 370.5, 240.5);
}

void drawMainMenuButtons() {
  strokeWeight(3);
  rectMode(CENTER);
  textAlign(CENTER, CENTER);
  textFont(fontRegular, 17);

  updateMainMenuHover();

  drawMenuButton(188.5, 200.5, "Play",     hoverPlay);
  drawMenuButton(188.5, 272.5, "Settings", hoverSettings);
  drawMenuButton(188.5, 344.5, "Help",     hoverHelp);
  drawMenuButton(552.5, 200.5, "Credit",   hoverCredits);
  drawMenuButton(552.5, 272.5, "Exit",     hoverExit);
}

void updateMainMenuHover() {
  hoverPlay = hoverSettings = hoverHelp = hoverCredits = hoverExit = false;

  if      (isMouseOverButton(188.5, 200.5)) { cursor(HAND); hoverPlay     = true; }
  else if (isMouseOverButton(188.5, 272.5)) { cursor(HAND); hoverSettings = true; }
  else if (isMouseOverButton(188.5, 344.5)) { cursor(HAND); hoverHelp     = true; }
  else if (isMouseOverButton(552.5, 200.5)) { cursor(HAND); hoverCredits  = true; }
  else if (isMouseOverButton(552.5, 272.5)) { cursor(HAND); hoverExit     = true; }
  else                                       { cursor(ARROW); }
}

void drawMenuButton(float x, float y, String label, boolean hover) {
  if (hover) { fill(COL_ACCENT);     stroke(COL_BTN_HOVER_STROKE); }
  else       { fill(COL_WINDOW_BG);  stroke(COL_WINDOW_STROKE);    }
  rect(x, y, 124, 57, 2);
  fill(COL_PRIMARY);
  text(label, x, y);
}

// ── Settings window ────────────────────────────────────────────────────────────

void drawSettingsWindow() {
  drawWindowBackground();

  textFont(fontBold, 17);
  fill(COL_PRIMARY);
  textAlign(CENTER, CENTER);
  text("Settings", 370.5, 187.5);

  textFont(fontRegular, 17);
  textAlign(LEFT, TOP);
  fill(COL_PRIMARY);
  text("Cannonball Size",   169.5, CTRL_SIZE_Y);
  text("Number of Targets", 169.5, CTRL_TGTS_Y);
  text("Difficulty Level",  169.5, 279);
  text("Disable Guideline", 169.5, CTRL_CHK_Y);

  drawSettingsStepper(int(ballRadius), CTRL_SIZE_Y);
  drawSettingsStepper(targetCount,     CTRL_TGTS_Y);
  drawGuidelineToggle();
  drawWindowCloseButton();
  updateSettingsCursor();
}

void drawWindowBackground() {
  stroke(COL_WINDOW_STROKE);
  fill(COL_WINDOW_BG);
  rectMode(CENTER);
  rect(centreX, centreY, 488, 245, 2);
}

void drawSettingsStepper(int value, float rowY) {
  fill(COL_PRIMARY);
  textFont(fontRegular, 17);
  textAlign(LEFT, TOP);
  text(value, CTRL_VALUE_X, rowY);

  image(isMouseOverRect(CTRL_LEFT_X,  rowY, 20, 20) ? imgLeftArrowHover  : imgLeftArrow,  CTRL_LEFT_X,  rowY);
  image(isMouseOverRect(CTRL_RIGHT_X, rowY, 20, 20) ? imgRightArrowHover : imgRightArrow, CTRL_RIGHT_X, rowY);
}

void drawGuidelineToggle() {
  boolean hover = isMouseOverRect(CTRL_CHK_X, CTRL_CHK_Y, 20, 20);
  PImage img = guidelineHidden
    ? (hover ? imgCheckedHover   : imgChecked)
    : (hover ? imgUncheckedHover : imgUnchecked);
  image(img, CTRL_CHK_X, CTRL_CHK_Y);
}

void drawWindowCloseButton() {
  image(isMouseOverRect(CTRL_CLOSE_X, CTRL_CLOSE_Y, 20, 20) ? imgCloseHover : imgClose,
        CTRL_CLOSE_X, CTRL_CLOSE_Y);
}

void updateSettingsCursor() {
  boolean onInteractive = isMouseOverRect(CTRL_CLOSE_X, CTRL_CLOSE_Y, 20, 20)
                       || isMouseOverRect(CTRL_LEFT_X,  CTRL_SIZE_Y,  20, 20)
                       || isMouseOverRect(CTRL_RIGHT_X, CTRL_SIZE_Y,  20, 20)
                       || isMouseOverRect(CTRL_LEFT_X,  CTRL_TGTS_Y,  20, 20)
                       || isMouseOverRect(CTRL_RIGHT_X, CTRL_TGTS_Y,  20, 20)
                       || isMouseOverRect(CTRL_CHK_X,   CTRL_CHK_Y,   20, 20);
  cursor(onInteractive ? HAND : ARROW);
}

// ── Instructions window ────────────────────────────────────────────────────────

void drawInstructionsWindow() {
  drawWindowBackground();

  textFont(fontBold, 17);
  fill(COL_PRIMARY);
  textAlign(CENTER, CENTER);
  text("Instructions", 370.5, 187.5);

  textFont(fontRegular, 17);
  textAlign(LEFT, CENTER);
  text(
    "1: To start, move cannonball away.\n"
    + "2: Change angle of projectile within the guides.\n"
    + "3: Change speed of cannonball by pulling away.\n"
    + "4: Release cannonball to fire shot.\n"
    + "5: To win, score more than high score.",
    169.5, centreY
  );

  drawSimpleCloseButton();
}

void drawSimpleCloseButton() {
  boolean hover = isMouseOverRect(CTRL_CLOSE_X, CTRL_CLOSE_Y, 20, 20);
  image(hover ? imgCloseHover : imgClose, CTRL_CLOSE_X, CTRL_CLOSE_Y);
  cursor(hover ? HAND : ARROW);
}

// ── Credits window ─────────────────────────────────────────────────────────────

void drawCreditWindow() {
  drawWindowBackground();

  textFont(fontScript, 24);
  fill(COL_PRIMARY);
  textAlign(CENTER, CENTER);
  text("Anas Uddin", centreX, 187.5);
  image(imgFlower, 420.11, 156.31);

  textFont(fontRegular, 17);
  text("Developed with love by\nAnas Uddin", centreX, centreY);

  drawCreditButtons();
}

void drawCreditButtons() {
  boolean onClose  = isMouseOverRect(CTRL_CLOSE_X, CTRL_CLOSE_Y, 20, 20);
  boolean onGithub = isMouseOverRect(355, 334, 30, 30);

  image(onClose  ? imgCloseHover  : imgClose,  CTRL_CLOSE_X, CTRL_CLOSE_Y);
  image(onGithub ? imgGithubHover : imgGithub, 355, 334);
  cursor(onClose || onGithub ? HAND : ARROW);
}

// ── Input ──────────────────────────────────────────────────────────────────────

void mousePressed() {
  if (showSettings) {
    handleSettingsClick();
  } else if (showInstructions) {
    if (isMouseOverRect(CTRL_CLOSE_X, CTRL_CLOSE_Y, 20, 20)) {
      showInstructions = false;
      showMainMenu     = true;
    }
  } else if (showCredits) {
    if (isMouseOverRect(CTRL_CLOSE_X, CTRL_CLOSE_Y, 20, 20)) {
      showCredits  = false;
      showMainMenu = true;
    } else if (isMouseOverRect(355, 334, 30, 30)) {
      link("https://github.com/theanasuddin");
    }
  } else if (showMainMenu) {
    handleMainMenuClick();
  } else if (isGameOver) {
    handleGameOverClick();
  } else {
    // Gameplay — begin aiming
    if (hitTestCircle(mouseX, mouseY, CANNON_X, CANNON_Y, ballRadius)) {
      isAiming = true;
    }
  }
}

void handleSettingsClick() {
  if (isMouseOverRect(CTRL_CLOSE_X, CTRL_CLOSE_Y, 20, 20)) {
    saveSettings("settings.txt");
    showSettings = false;
    showMainMenu = true;
  } else if (isMouseOverRect(CTRL_LEFT_X, CTRL_SIZE_Y, 20, 20)) {
    ballRadius = max(ballRadius - 1, BALL_RADIUS_MIN);
  } else if (isMouseOverRect(CTRL_RIGHT_X, CTRL_SIZE_Y, 20, 20)) {
    ballRadius = min(ballRadius + 1, BALL_RADIUS_MAX);
  } else if (isMouseOverRect(CTRL_LEFT_X, CTRL_TGTS_Y, 20, 20)) {
    targetCount = max(targetCount - 1, TARGETS_MIN);
  } else if (isMouseOverRect(CTRL_RIGHT_X, CTRL_TGTS_Y, 20, 20)) {
    targetCount = min(targetCount + 1, TARGETS_MAX);
  } else if (isMouseOverRect(CTRL_CHK_X, CTRL_CHK_Y, 20, 20)) {
    guidelineHidden = !guidelineHidden;
  }
}

void handleMainMenuClick() {
  if      (isMouseOverButton(188.5, 200.5)) { startGame(); }
  else if (isMouseOverButton(188.5, 272.5)) { showMainMenu = false; showSettings     = true; }
  else if (isMouseOverButton(188.5, 344.5)) { showMainMenu = false; showInstructions = true; }
  else if (isMouseOverButton(552.5, 200.5)) { showMainMenu = false; showCredits      = true; }
  else if (isMouseOverButton(552.5, 272.5)) { exit(); }
}

void handleGameOverClick() {
  if (isMouseOver(centreX, centreY, 124, 57)) {
    resetGame();
  } else if (isMouseOver(centreX, centreY + 106, 124, 57)) {
    isGameOver   = false;
    showMainMenu = true;
  }
}

void mouseReleased() {
  if (isAiming) isInFlight = true;
}

// ── Game flow ──────────────────────────────────────────────────────────────────

void startGame() {
  showMainMenu = false;
  isGameOver   = false;
  nextRound();
}

void nextRound() {
  angle      = 0;
  velocity   = 0;
  isAiming   = false;
  isInFlight = false;
  isGameOver = false;
  isWin      = false;
  targetIndex = (int) random(0, targetCount);
}

void resetGame() {
  score     = 0;
  highScore = loadHighScore("high_score.txt");
  nextRound();
}

void endFlight() {
  isInFlight = false;
  flightTime = 0;
}

void triggerGameOver() {
  isGameOver = true;
  checkHighScore();
}

// ── Persistence ────────────────────────────────────────────────────────────────

int loadHighScore(String fileName) {
  try {
    String[] lines = loadStrings(fileName);
    if (lines != null && lines.length > 0) return int(lines[0]);
  } catch (Exception e) { /* fall through */ }
  return 0;
}

void checkHighScore() {
  if (score > highScore) {
    isWin     = true;
    highScore = score;
    try {
      saveStrings("data/high_score.txt", new String[]{ str(score) });
    } catch (Exception e) { e.printStackTrace(); }
  }
}

void loadSettings(String fileName) {
  try {
    String[] lines = loadStrings(fileName);
    if (lines == null) return;
    if (lines.length >= 1) targetCount     = constrain(int(lines[0]), TARGETS_MIN,    TARGETS_MAX);
    if (lines.length >= 2) guidelineHidden = "true".equals(lines[1]);
    if (lines.length >= 3) ballRadius      = constrain(int(lines[2]), BALL_RADIUS_MIN, BALL_RADIUS_MAX);
  } catch (Exception e) { /* use defaults */ }
}

void saveSettings(String fileName) {
  try {
    saveStrings("data/" + fileName, new String[]{
      str(targetCount),
      guidelineHidden ? "true" : "false",
      str(int(ballRadius))
    });
  } catch (Exception e) { e.printStackTrace(); }
}

// ── Utilities ──────────────────────────────────────────────────────────────────

boolean hitTestCircle(float mx, float my, float ox, float oy, float r) {
  float dx = mx - ox, dy = my - oy;
  return dx * dx + dy * dy <= r * r;
}

// Top-left origin rect test
boolean isMouseOverRect(float x, float y, float w, float h) {
  return mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h;
}

// Centre-origin rect test
boolean isMouseOver(float cx, float cy, float w, float h) {
  return mouseX >= cx - w / 2 && mouseX <= cx + w / 2
      && mouseY >= cy - h / 2 && mouseY <= cy + h / 2;
}

boolean isMouseOverButton(float bx, float by) {
  return isMouseOver(bx, by, 124, 57);
}
