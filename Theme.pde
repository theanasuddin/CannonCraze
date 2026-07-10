// -- Theme: design system: palette, typography, drawing primitives -------------

// Ink
final color INK       = #EEF1FF;
final color INK_DIM   = #9AA2C8;
final color INK_FAINT = #565C86;

// Brand
final color ACCENT      = #2FE8D8;
final color ACCENT_SOFT = #8FF7EC;
final color ACCENT_DEEP = #0FA89B;
final color VIOLET      = #7B6CFF;
final color CORAL       = #FF6E7E;
final color GOLD        = #FFC96B;

// Scene
final color SKY_TOP     = #030210;
final color SKY_MID     = #0A0733;
final color SKY_HORIZON = #1A1156;
final color MOUNT_FAR   = #110B38;
final color MOUNT_NEAR  = #0A0626;
final color GROUND      = #070414;

// Surfaces
final color PANEL_BG      = #0B0A26;
final color PANEL_LINE    = #7E86CD;
final color METAL         = #14103C;   // cannon barrel
final color METAL_LIGHT   = #191349;   // cannon dome
final color BTN_TEXT_DARK = #04222B;   // text on filled accent buttons

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
  if (fontBold    == null) fontBold    = createFont("SansSerif-Bold", 96);
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

// -- Easing ---------------------------------------------------------------------

float easeOutCubic(float p) {
  return 1 - pow(1 - constrain(p, 0, 1), 3);
}

// -- Tracked (letter-spaced) text -----------------------------------------------
// Set textFont/textSize before calling; fill applies as usual.

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

// -- Glow primitives ------------------------------------------------------------

// Both glow primitives honor the quality governor: lower tiers draw fewer
// halo passes, keeping the bright core and shedding the faint outer layers.
void glowCircle(float x, float y, float r, color c, float strength) {
  pushStyle();
  noStroke();
  for (int i = qGlowPasses(); i >= 1; i--) {
    fill(c, strength / (i * i));
    circle(x, y, (r + i * i * 2.4) * 2);
  }
  popStyle();
}

void glowLine(float x1, float y1, float x2, float y2, color c, float coreW, float strength) {
  pushStyle();
  for (int i = qLinePasses(); i >= 1; i--) {
    stroke(c, strength / (i * i + 1));
    strokeWeight(coreW + i * i * 2.0);
    line(x1, y1, x2, y2);
  }
  stroke(c, min(255, strength * 1.7));
  strokeWeight(coreW);
  line(x1, y1, x2, y2);
  popStyle();
}

// -- Panel (glass card) ---------------------------------------------------------

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
  strokeWeight(1.2);
  rect(cx, cy, w, h, r);

  stroke(255, 15 * alphaMul);
  strokeWeight(1);
  line(cx - w / 2 + r, cy - h / 2 + 1.2, cx + w / 2 - r, cy - h / 2 + 1.2);
  popStyle();
}
