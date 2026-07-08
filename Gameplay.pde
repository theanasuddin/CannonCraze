// -- Gameplay: cannon, aiming, flight, targets, HUD, game-over overlay -----------

void drawGameplay() {
  drawBackground();

  pushMatrix();
  if (shakeT > 0.01) {
    float m = 7 * shakeT * shakeT;
    translate(random(-m, m), random(-m, m));
    shakeT = lerp(shakeT, 0, 0.09);
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

  if (isGameOver) {
    drawGameOverOverlay();
  } else if (isAiming || (!isInFlight && overGrabZone())) {
    wantHand = true;
  }
}

// -- Platform / cannon --------------------------------------------------------------

void drawPlatform() {
  // The platform is anchored to the design region but pours out to the world's
  // left and bottom edges so wide or tall windows never show a floating slab.
  // The slanted face keeps the same slope it has inside the design region.
  float wl = worldLeft() - 2;
  float wb = worldBottom() + 2;
  float slantX = 168 + (232 - 168) / (VIEW_H + 2 - PLATFORM_TOP) * (wb - PLATFORM_TOP);

  pushStyle();
  noStroke();
  fill(#0D0A2C);
  quad(wl, PLATFORM_TOP, 168, PLATFORM_TOP, slantX, wb, wl, wb);
  glowLine(wl, PLATFORM_TOP, 168, PLATFORM_TOP, ACCENT, 1.4, 70);
  stroke(ACCENT, 36);
  strokeWeight(1.2);
  line(168, PLATFORM_TOP, slantX, wb);
  popStyle();
}

void drawCannon() {
  float targetA = isAiming ? angle - PI : (isInFlight ? barrelAngle : -QUARTER_PI);
  barrelAngle = lerp(barrelAngle, targetA, 0.3);
  recoilT     = max(0, recoilT - 0.07);

  pushStyle();
  pushMatrix();
  translate(CANNON_X, CANNON_Y);
  rotate(barrelAngle);
  translate(-6 * easeOutCubic(recoilT), 0);

  rectMode(CORNER);
  fill(#1D1852);
  stroke(PANEL_LINE, 165);
  strokeWeight(1.3);
  rect(-10, -9, BARREL_LEN + 12, 18, 9);

  stroke(255, 30);
  strokeWeight(1);
  line(-4, -5.5, BARREL_LEN - 6, -5.5);

  noStroke();
  fill(ACCENT, 220 + 35 * recoilT);
  rect(BARREL_LEN - 3, -9, 4.5, 18, 2);
  popMatrix();

  noStroke();
  fill(METAL_LIGHT);
  arc(CANNON_X, PLATFORM_TOP + 2, 56, 56, PI, TWO_PI);
  noFill();
  stroke(ACCENT, 70);
  strokeWeight(1.3);
  arc(CANNON_X, PLATFORM_TOP + 2, 56, 56, PI, TWO_PI);
  popStyle();
}

float muzzleX() { return CANNON_X + cos(barrelAngle) * BARREL_LEN; }
float muzzleY() { return CANNON_Y + sin(barrelAngle) * BARREL_LEN; }

float restBallX() { return CANNON_X + cos(barrelAngle) * (BARREL_LEN + ballRadius * 0.4); }
float restBallY() { return CANNON_Y + sin(barrelAngle) * (BARREL_LEN + ballRadius * 0.4); }

boolean overGrabZone() {
  return !isGameOver
      && dist(vmx, vmy, restBallX(), restBallY()) <= max(ballRadius + 12, 26);
}

// -- Ball rendering -------------------------------------------------------------

void drawBall(float x, float y) {
  pushStyle();
  glowCircle(x, y, ballRadius, ACCENT, 90);
  noStroke();
  fill(ACCENT);
  circle(x, y, ballRadius * 2);
  fill(#EAFFFC, 210);
  circle(x - ballRadius * 0.28, y - ballRadius * 0.32, ballRadius * 0.85);
  popStyle();
}

void drawIdleBall() {
  float bx = restBallX(), by = restBallY();
  drawBall(bx, by);

  float pu = 0.5 + 0.5 * sin(tSec() * 2.4);
  pushStyle();
  noFill();
  stroke(ACCENT, 50 + 60 * pu);
  strokeWeight(1.4);
  circle(bx, by, ballRadius * 2 + 11 + 4 * pu);
  popStyle();
}

// -- Aiming ---------------------------------------------------------------------

void updateAim() {
  float ax = min(vmx, CANNON_X - 0.01);
  float ay = max(vmy, CANNON_Y + 0.01);

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
  strokeWeight(1.6);
  line(mx, my, aimX, aimY);

  noStroke();
  fill(ACCENT, 46);
  circle(aimX, aimY, ballRadius * 2 + 10);
  fill(#0B1B2A);
  stroke(ACCENT, 230);
  strokeWeight(1.6);
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
    float t  = i * 0.32;
    float px = CANNON_X - vx * t;
    float py = GRAVITY * t * t - vy * t + CANNON_Y;
    if (py > TARGET_ROW_Y + 8 || px > worldRight() + 20) break;
    float f = 1 - i / (float) n;
    fill(ACCENT, 20 + 150 * f);
    circle(px, py, 2 + 5.2 * f);
  }
  popStyle();
}

// -- Flight ---------------------------------------------------------------------

void updateProjectile() {
  float t  = flightTime;
  float vx = velocity * cos(angle);
  float vy = velocity * sin(angle);
  float px = CANNON_X - vx * t;
  float py = GRAVITY * t * t - vy * t + CANNON_Y;

  spawnTrail(px, py, ballRadius * 0.9);
  drawBall(px, py);
  flightTime += 0.1;

  // Complete miss: fell past the bottom of the window
  if (py > worldBottom() + ballRadius) {
    endFlight();
    triggerGameOver();
    return;
  }

  // Weak lob that dropped back onto the cannon platform
  if (t > 0.5 && px <= 208 && py >= PLATFORM_TOP - ballRadius) {
    endFlight();
    spawnBurst(px, PLATFORM_TOP - 2, CORAL, 18, 2.6);
    triggerGameOver();
    return;
  }

  // Reached the pad row
  if (py >= TARGET_ROW_Y - ballRadius && px >= TARGET_X && px <= TARGET_RIGHT) {
    endFlight();
    float cellW = TARGET_W / targetCount;
    int   cell  = constrain(int((px - TARGET_X) / cellW), 0, targetCount - 1);
    if (cell == targetIndex) {
      score++;
      sfxHit(score);
      scorePop  = 1;
      padFlash  = 1;
      padFlashX = TARGET_X + cell * cellW;
      padFlashW = cellW;
      spawnBurst(px, TARGET_ROW_Y - 4, ACCENT, 26, 3.4);
      spawnRing(px, TARGET_ROW_Y - 2, ACCENT);
      spawnScoreFloat(px, TARGET_ROW_Y - 26);
      nextRound();
    } else {
      spawnBurst(px, TARGET_ROW_Y - 4, CORAL, 22, 3.0);
      triggerGameOver();
    }
  }
}

// -- Targets --------------------------------------------------------------------

void drawTargets() {
  float cellW = TARGET_W / targetCount;
  float gap   = min(7, cellW * 0.14);

  pushStyle();
  rectMode(CORNER);
  for (int i = 0; i < targetCount; i++) {
    float x  = TARGET_X + i * cellW;
    float px = x + gap / 2;
    float pw = cellW - gap;

    if (i == targetIndex && !isGameOver) {
      float pu = 0.5 + 0.5 * sin(tSec() * 3.2);
      drawLightColumn(px + pw / 2, TARGET_ROW_Y, pw * 0.72, 170, 16 + 12 * pu);
      noStroke();
      fill(ACCENT, 30);
      rect(px - 3, TARGET_ROW_Y - 3, pw + 6, TARGET_H + 6, 8);
      fill(ACCENT, 70 + 50 * pu);
      stroke(ACCENT, 235);
      strokeWeight(1.4);
      rect(px, TARGET_ROW_Y, pw, TARGET_H, 5);
    } else {
      fill(PANEL_LINE, 26);
      stroke(PANEL_LINE, 85);
      strokeWeight(1);
      rect(px, TARGET_ROW_Y, pw, TARGET_H, 5);
    }
  }

  if (padFlash > 0.01) {
    noStroke();
    fill(255, 190 * padFlash);
    rect(padFlashX + gap / 2, TARGET_ROW_Y, padFlashW - gap, TARGET_H, 5);
    padFlash = max(0, padFlash - 0.05);
  }
  popStyle();
}

void drawLightColumn(float cx, float bottomY, float w, float h, float maxAlpha) {
  pushStyle();
  rectMode(CORNER);
  noStroke();
  int slices = 30;
  for (int i = 0; i < slices; i++) {
    float f = i / (float) slices;             // 0 at pad → 1 at top
    fill(ACCENT, maxAlpha * (1 - f) * (1 - f));
    float sw = w * (1 - f * 0.35);
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

  scorePop = max(0, scorePop - 0.05);
  float s = 1 + 0.4 * easeOutCubic(scorePop);
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
    trackedTextL("ANGLE " + deg + "°    POWER " + pct + "%", 36, 584, 2.5);
  } else if (!isGameOver) {
    float pu = 0.5 + 0.5 * sin(tSec() * 2.4);
    fill(INK_FAINT, 150 + 70 * pu);
    trackedTextL("PULL THE GLOWING BALL TO AIM · RELEASE TO FIRE", 36, 584, 2.5);
  }

  fill(INK_FAINT, 110);
  trackedTextR("ESC · MENU", 924, 584, 2.5);
  popStyle();
}

// -- Game-over overlay ----------------------------------------------------------

void drawGameOverOverlay() {
  overlayT = lerp(overlayT, 1, 0.14);
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

  textFont(fontRegular, 11.5);
  fill(INK_FAINT, 255 * e);
  trackedTextC("BEST  " + highScore, centreX, cy + 44, 3);
  popStyle();

  btnAgain.y    = cy + 96;
  btnMenuOver.y = cy + 96;
  btnAgain.render(overlayT > 0.5);
  btnMenuOver.render(overlayT > 0.5);

  updateParticles();   // record confetti renders above the dim layer
}
