// -- Ui: buttons, modal windows, settings widgets ---------------------------------

final int ICON_MINUS = 0;
final int ICON_PLUS  = 1;
final int ICON_CLOSE = 2;

// Modal geometry. Settings carries more rows than the other cards, so each
// modal picks its own height around the shared centre.
final float CARD_X = 480, CARD_Y = 300, CARD_W = 540, CARD_R = 22;

float modalHeight() {
  return (modalId == MODAL_SETTINGS) ? 500 : 392;
}

IconBtn  icoClose, icoSizeMinus, icoSizePlus, icoTgtsMinus, icoTgtsPlus;
UIToggle tglGuide, tglSound;
UISlider sldVolume;

// -- Widgets ------------------------------------------------------------------------

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
    boolean hot = interactive && contains(vmx, vmy);
    if (hot) wantHand = true;
    hov = lerp(hov, hot ? 1 : 0, 0.22);

    pushStyle();
    rectMode(CENTER);
    float r = h / 2;

    if (primary) {
      if (hov > 0.02) {
        noStroke();
        for (int i = 3; i >= 1; i--) {
          fill(ACCENT, 22 * hov / i);
          rect(x, y, w + i * 7, h + i * 7, r + i * 4);
        }
      }
      noStroke();
      fill(lerpColor(ACCENT, ACCENT_SOFT, 0.45 * hov));
      rect(x, y, w, h, r);
      fill(BTN_TEXT_DARK);
      textFont(fontBold, 13);
      trackedTextC(label, x, y - 1, 2.6);
    } else {
      stroke(lerpColor(PANEL_LINE, ACCENT, hov), 95 + 130 * hov);
      strokeWeight(1.2);
      fill(ACCENT, 16 * hov);
      rect(x, y, w, h, r);
      fill(lerpColor(#C7CCE8, ACCENT_SOFT, hov));
      textFont(fontBold, 12.5);
      trackedTextC(label, x, y - 1, 2.6);
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
    return enabled && dist(mx, my, x, y) <= 19;
  }

  void render(boolean interactive, float alphaMul) {
    boolean hot = interactive && enabled && contains(vmx, vmy);
    if (hot) wantHand = true;
    hov = lerp(hov, hot ? 1 : 0, 0.25);

    color hi = (kind == ICON_CLOSE) ? CORAL : ACCENT;
    float dimA = enabled ? 1 : 0.32;

    pushStyle();
    stroke(lerpColor(PANEL_LINE, hi, hov), 100 * dimA * alphaMul + 120 * hov);
    strokeWeight(1.2);
    fill(hi, 16 * hov);
    circle(x, y, 34);

    stroke(lerpColor(INK_DIM, hi, hov), 255 * dimA * alphaMul);
    strokeWeight(1.6);
    if (kind == ICON_MINUS) {
      line(x - 5.5, y, x + 5.5, y);
    } else if (kind == ICON_PLUS) {
      line(x - 5.5, y, x + 5.5, y);
      line(x, y - 5.5, x, y + 5.5);
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
    boolean hot = interactive && contains(vmx, vmy);
    if (hot) wantHand = true;
    anim = lerp(anim, on ? 1 : 0, 0.25);

    pushStyle();
    rectMode(CENTER);
    noStroke();
    fill(lerpColor(#232349, ACCENT_DEEP, anim), 255 * alphaMul);
    rect(x, y, 52, 28, 14);
    if (anim > 0.05) {
      noFill();
      stroke(ACCENT, 90 * anim * alphaMul);
      strokeWeight(1.2);
      rect(x, y, 52, 28, 14);
    }
    noStroke();
    fill(lerpColor(INK_DIM, INK, anim), 255 * alphaMul);
    circle(x + lerp(-12, 12, anim), y, 20);
    popStyle();
  }
}

// A draggable volume slider. The knob follows the mouse while dragging (state
// driven from the sketch's mouse handlers) and a soft tick sounds at every five
// percent step, so the loudness can be judged while it is being set.
class UISlider {
  float x, y, w;       // left end of the track, centre line, track width
  boolean dragging = false;
  float hov = 0;

  UISlider(float x, float y, float w) {
    this.x = x;  this.y = y;  this.w = w;
  }

  boolean contains(float mx, float my) {
    return mx >= x - 12 && mx <= x + w + 12 && abs(my - y) <= 16;
  }

  void setFromMouse(float mx) {
    float v = constrain((mx - x) / w, 0, 1);
    int oldStep = round(soundVolume * 20);
    soundVolume = v;
    if (round(v * 20) != oldStep) sfxTick();
  }

  void render(boolean interactive, float alphaMul, boolean enabled) {
    boolean hot = interactive && enabled && (dragging || contains(vmx, vmy));
    if (hot) wantHand = true;
    hov = lerp(hov, hot ? 1 : 0, 0.25);

    float dimA = enabled ? 1 : 0.32;
    float kx   = x + soundVolume * w;

    pushStyle();
    // track, then the filled portion up to the knob
    stroke(PANEL_LINE, 80 * dimA * alphaMul);
    strokeWeight(4);
    line(x, y, x + w, y);
    if (kx > x + 0.5) {
      stroke(ACCENT, (150 + 70 * hov) * dimA * alphaMul);
      line(x, y, kx, y);
    }

    // knob with a soft halo on hover / drag
    noStroke();
    if (hov > 0.02 && enabled) {
      fill(ACCENT, 36 * hov * alphaMul);
      circle(kx, y, 34);
    }
    fill(lerpColor(INK_DIM, INK, enabled ? 0.65 + 0.35 * hov : 0), 255 * dimA * alphaMul);
    circle(kx, y, 18);
    noFill();
    stroke(ACCENT, (110 + 130 * hov) * dimA * alphaMul);
    strokeWeight(1.2);
    circle(kx, y, 18);

    // live percentage rides under the knob
    fill(INK_FAINT, 235 * dimA * alphaMul);
    textFont(fontRegular, 9.5);
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
    saveSettings("settings.txt");
  }
  modalId = MODAL_NONE;
  sfxClick();
}

void drawModal() {
  modalT = lerp(modalT, 1, 0.18);
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
  icoClose.render(modalT > 0.5, e);
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
  textFont(fontRegular, 12.5);
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
  text(int(ballRadius), 615, rowSize - 1);
  text(targetCount,     615, rowTgts - 1);

  textFont(fontRegular, 9.5);
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

  boolean live = modalT > 0.5;
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
  "Grab the glowing cannonball at the muzzle.",
  "Pull back. Distance sets power, direction sets angle.",
  "Release to fire the shot.",
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
    trackedTextL("0" + (i + 1), CARD_X - CARD_W / 2 + 62, y, 1.5);
    textAlign(LEFT, CENTER);
    textFont(fontRegular, 13);
    fill(#C9CFEA, 255 * e);
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
  trackedTextC("DESIGNED  &  DEVELOPED  WITH  CARE", CARD_X, cardTop + 226, 2.5);
  popStyle();

  btnGithub.y = cardTop + 300;
  btnGithub.render(modalT > 0.5);
}

// -- Modal input ---------------------------------------------------------------------------

void handleModalClick() {
  // Click outside the card dismisses it
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
    saveSettings("settings.txt");
  } else if (modalId == MODAL_CREDITS) {
    if (btnGithub.contains(vmx, vmy)) {
      sfxClick();
      link("https://github.com/theanasuddin");
    }
  }
}
