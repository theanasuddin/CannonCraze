// ── Background — night-sky scene shared by every screen ────────────────────────
// The static parts (sky gradient, nebula glows, planet, mountains) render once
// into a buffer; stars twinkle and meteors streak on top each frame.

PGraphics bgScene;

final int STAR_COUNT = 150;
float[] starX  = new float[STAR_COUNT];
float[] starY  = new float[STAR_COUNT];
float[] starSz = new float[STAR_COUNT];
float[] starPh = new float[STAR_COUNT];
float[] starSp = new float[STAR_COUNT];

final float PLANET_X = 756, PLANET_Y = 128, PLANET_R = 58;

// Meteor
boolean mtActive = false;
float   mtX, mtY, mtVX, mtVY, mtAge, mtLife;
float   meteorTimer = 5;

void buildBackground() {
  bgScene = createGraphics(width, height);
  bgScene.beginDraw();

  for (int y = 0; y < height; y++) {
    float f = y / (float) height;
    color c = (f < 0.55)
      ? lerpColor(SKY_TOP, SKY_MID, f / 0.55)
      : lerpColor(SKY_MID, SKY_HORIZON, (f - 0.55) / 0.45);
    bgScene.stroke(c);
    bgScene.line(0, y, width, y);
  }
  bgScene.noStroke();

  radialGlow(bgScene, 240, 130, 330, VIOLET, 8);
  radialGlow(bgScene, 820, 330, 380, ACCENT_DEEP, 6);

  drawPlanet(bgScene, PLANET_X, PLANET_Y, PLANET_R);

  noiseSeed(11);
  drawRidge(bgScene, 452, 62, 0.0042, 0,  MOUNT_FAR);
  drawRidge(bgScene, 516, 48, 0.0060, 57, MOUNT_NEAR);
  bgScene.noStroke();
  bgScene.fill(GROUND);
  bgScene.rect(0, 568, width, height - 568);

  bgScene.endDraw();

  randomSeed(7);
  for (int i = 0; i < STAR_COUNT; i++) {
    float x, y;
    do {
      x = random(width);
      y = random(430);
    } while (dist(x, y, PLANET_X, PLANET_Y) < PLANET_R * 2.4);
    starX[i]  = x;
    starY[i]  = y;
    starSz[i] = random(0.8, 2.4);
    starPh[i] = random(TWO_PI);
    starSp[i] = random(0.5, 1.6);
  }
  randomSeed((int) System.currentTimeMillis());
}

void radialGlow(PGraphics g, float x, float y, float r, color c, float coreAlpha) {
  g.noStroke();
  int steps = 24;
  for (int i = steps; i >= 1; i--) {
    float f = i / (float) steps;
    g.fill(c, coreAlpha * (1 - f) * (1 - f) + 0.4);
    g.circle(x, y, 2 * r * f);
  }
}

void drawPlanet(PGraphics g, float x, float y, float r) {
  radialGlow(g, x, y, r * 2.6, ACCENT, 9);

  g.pushMatrix();
  g.translate(x, y);
  g.rotate(radians(-16));
  g.noFill();
  g.stroke(ACCENT_SOFT, 60);
  g.strokeWeight(1.5);
  g.arc(0, 0, r * 3.5, r * 1.05, PI, TWO_PI);   // ring, far side
  g.popMatrix();

  g.noStroke();
  g.fill(#171150);
  g.circle(x, y, r * 2);

  // rim light on the side facing the scene
  g.noFill();
  g.stroke(ACCENT, 120);
  g.strokeWeight(2);
  g.arc(x, y, r * 2 - 2, r * 2 - 2, HALF_PI + 0.5, PI + 1.1);

  g.pushMatrix();
  g.translate(x, y);
  g.rotate(radians(-16));
  g.noFill();
  g.stroke(ACCENT_SOFT, 110);
  g.strokeWeight(1.5);
  g.arc(0, 0, r * 3.5, r * 1.05, 0, PI);        // ring, near side
  g.popMatrix();
}

void drawRidge(PGraphics g, float baseY, float amp, float freq, float seedOff, color c) {
  g.noStroke();
  g.fill(c);
  g.beginShape();
  g.vertex(-2, height + 2);
  for (float x = -2; x <= width + 2; x += 5) {
    g.vertex(x, baseY - noise(x * freq + seedOff) * amp);
  }
  g.vertex(width + 2, height + 2);
  g.endShape(CLOSE);
}

// ── Per-frame layer ────────────────────────────────────────────────────────────

void drawBackground() {
  image(bgScene, 0, 0);
  drawStars();
  updateMeteor();
}

void drawStars() {
  pushStyle();
  noStroke();
  float t = tSec();
  for (int i = 0; i < STAR_COUNT; i++) {
    float tw = 0.6 + 0.4 * sin(t * starSp[i] * 2.2 + starPh[i]);
    float a  = (60 + 130 * (starSz[i] / 2.4)) * tw;
    fill(#DDE6FF, a);
    circle(starX[i], starY[i], starSz[i]);
    if (i % 19 == 0) {
      stroke(#DDE6FF, a * 0.35);
      strokeWeight(0.8);
      float f = 2.2 + starSz[i] * 1.6;
      line(starX[i] - f, starY[i], starX[i] + f, starY[i]);
      line(starX[i], starY[i] - f, starX[i], starY[i] + f);
      noStroke();
    }
  }
  popStyle();
}

void updateMeteor() {
  if (!mtActive) {
    meteorTimer -= 1 / 60.0;
    if (meteorTimer <= 0) {
      mtActive = true;
      mtX    = random(300, 940);
      mtY    = random(20, 130);
      float sp = random(6, 9);
      mtVX   = -sp * 0.92;
      mtVY   =  sp * 0.40;
      mtAge  = 0;
      mtLife = random(0.7, 1.1);
    }
    return;
  }

  mtAge += 1 / 60.0;
  mtX   += mtVX;
  mtY   += mtVY;
  if (mtAge >= mtLife) {
    mtActive    = false;
    meteorTimer = random(6, 13);
    return;
  }

  float u = mtAge / mtLife;
  float a = 180 * sin(u * PI);
  pushStyle();
  for (int k = 0; k < 6; k++) {
    float f = k / 6.0;
    stroke(#DDE6FF, a * (1 - f));
    strokeWeight(1.6 - f);
    line(mtX - mtVX * f * 4,       mtY - mtVY * f * 4,
         mtX - mtVX * (f + 0.16) * 4, mtY - mtVY * (f + 0.16) * 4);
  }
  noStroke();
  fill(#FFFFFF, a);
  circle(mtX, mtY, 2.2);
  popStyle();
}
