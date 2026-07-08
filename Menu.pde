// -- Main menu ---------------------------------------------------------------------

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
  shapeMode(CENTER);
  noStroke();
  fill(ACCENT);
  shape(shapeLogo, centreX, 118, 70, 56.4);

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
  boolean interactive = (modalId == MODAL_NONE) && fadeT < 0.5;
  for (UIButton b : menuBtns) b.render(interactive);
}

void drawMenuFooter() {
  pushStyle();
  textFont(fontRegular, 10.5);
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
  else if (menuBtns[4].contains(vmx, vmy)) exit();
}
