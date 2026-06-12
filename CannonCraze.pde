float CANNONBALL_RADIUS = 25 / 2;
final float TARGET_WIDTH = 55;
final float TARGET_HEIGHT = 24;
final float GUIDELINE_LENGTH = 55;
final float CANNONBALL_POS_X = 108.5;
final float CANNONBALL_POS_Y = 327.5;
final float MAXIMUM_VELOCITY = 150;

boolean aimCannonballState = false;
boolean isProjectilePathActive = false;
boolean isWin = false;
boolean isGameOver = false;
boolean playAgainHover, mainMenuButtonHover;
boolean playHover, settingsHover, exitHover, helpHover, creditHover;
boolean isMainMenuActive = true;
boolean isInstructionsWindowActive = false, isCreditWindowActive = false;
boolean isSettingsWindowActive = false;
boolean isGuidelineDisabled = false;

float angle = 0;
float velocity = 0;
float time = 0;
float desiredTragetPositionX;
int desiredTragetIndex = (int)random(0, 10);
float centreX, centreY;
int score = 0;
int highScore;

PImage gameBackground;
PImage menuBackground;
PImage closeButton;
PImage closeButtonHover;
PImage flower;
PImage github, githubHover;
PImage icon;   //Game icon.
PImage checkedCheckbox;
PImage checkedCheckboxHover;
PImage uncheckedCheckbox;
PImage uncheckedCheckboxHover;
PImage leftArrow;
PImage leftArrowHover;
PImage rightArrow;
PImage rightArrowHover;

PFont montserratRegular, montserratBold, playlistScript;

PShape cannonLogo;

void setup() {
  size(740, 545);
  surface.setTitle("Cannon Craze");
  icon = loadImage("icon.png");   //Load the icon.
  surface.setIcon(icon);
  centreX = width / 2;
  centreY = height / 2;
  highScore = loadHighScore("high_score.txt");
  gameBackground = loadImage("game_background.png");
  menuBackground = loadImage("menu_background.jpg");
  closeButton = loadImage("close_button.png");
  closeButtonHover = loadImage("close_button_hover.png");
  flower = loadImage("flower.png");
  github = loadImage("github.png");
  githubHover = loadImage("github_hover.png");
  checkedCheckbox = loadImage("checked_checkbox.png");
  checkedCheckboxHover = loadImage("checked_checkbox_hover.png");
  uncheckedCheckbox = loadImage("unchecked_checkbox.png");
  uncheckedCheckboxHover = loadImage("unchecked_checkbox_hover.png");
  leftArrow = loadImage("left_arrow.png");
  leftArrowHover = loadImage("left_arrow_hover.png");
  rightArrow = loadImage("right_arrow.png");
  rightArrowHover = loadImage("right_arrow_hover.png");
  montserratRegular = createFont("Montserrat-Regular.otf", 192);
  montserratBold = createFont("Montserrat-Bold.otf", 192);
  playlistScript = createFont("Playlist-Script.otf", 192);
}

void draw() {
  if (isSettingsWindowActive) {
    image(menuBackground, 0, 0);
    drawSettingsWindow();
  } else if (isInstructionsWindowActive) {
    image(menuBackground, 0, 0);
    drawInstructionsWindow();
  } else if (isCreditWindowActive) {
    image(menuBackground, 0, 0);
    drawCreditWindow();
  } else if (isMainMenuActive) {
    image(menuBackground, 0, 0);
    drawCannonLogo();
    drawMainMenuButtons();
  } else if (!isGameOver) {
    image(gameBackground, 0, 0);

    drawCliff();
    drawCurrentVelocityAndAngle(velocity, degrees(angle));
    drawCurrentScoreAndHighScore();
    desiredTragetPositionX = drawTargets(desiredTragetIndex);

    if (isProjectilePathActive) {
      drawCannonballAlongProjectilePath(time);
      time += 0.1;
    } else {
      drawCannonball();
    }

    if (!isGuidelineDisabled) {
      drawAngleGuides();
    }

    if (mousePressed && !isProjectilePathActive) {
      drawAimCannonball(aimCannonballState);
    } else {
      aimCannonballState = false;
    }

    switchCursor();
  } else {
    drawExitOptions();
  }
}

void drawCliff() {
  fill(#350528);
  strokeWeight(1);
  stroke(#3472C5);
  quad(-1, 324.5, 108.5, 327.5, 130.5, height, -1, height);
}

void drawCannonball() {
  fill(#26ECE2);
  stroke(#080340);
  strokeWeight(1);
  ellipse(CANNONBALL_POS_X, CANNONBALL_POS_Y, CANNONBALL_RADIUS * 2, CANNONBALL_RADIUS * 2);
}

float drawTargets(int desiredTragetPosition) {
  float initialTargetPosX = 162.5;
  float targetPosY = 521.5;
  float desiredTragetPositionX = 0;

  strokeWeight(1);
  rectMode(CORNER);
  for (int i = 0; i < 10; i++) {
    if (i == desiredTragetPosition) {
      fill(#26ECE2);
      desiredTragetPositionX = initialTargetPosX;
    } else {
      fill(#350528);
    }

    rect(initialTargetPosX, targetPosY, TARGET_WIDTH, TARGET_HEIGHT, 2);
    initialTargetPosX += 55;
  }

  return desiredTragetPositionX;
}

void drawAngleGuides() {
  // minimum angle guide
  strokeWeight(1);
  stroke(#3472C5);
  line(CANNONBALL_POS_X, CANNONBALL_POS_Y, CANNONBALL_POS_X + GUIDELINE_LENGTH, CANNONBALL_POS_Y);

  // maximum angle guide
  line(CANNONBALL_POS_X, CANNONBALL_POS_Y, CANNONBALL_POS_X, CANNONBALL_POS_Y - GUIDELINE_LENGTH);

  // active angle guide
  strokeWeight(5);
  if (aimCannonballState && !isProjectilePathActive) {
    float activeGuideEndpointX = CANNONBALL_POS_X - (GUIDELINE_LENGTH * cos(angle));
    float activeGuideEndpointY = CANNONBALL_POS_Y - (GUIDELINE_LENGTH * sin(angle));
    line(CANNONBALL_POS_X, CANNONBALL_POS_Y, activeGuideEndpointX, activeGuideEndpointY);
  }
}

boolean isMouseInsideTheCannonball(float x, float y, float xC, float yC, float radius) {
  float distanceSquared = (x - xC) * (x - xC) + (y - yC) * (y - yC);
  return distanceSquared <= radius * radius;
}

void mousePressed() {
  if (isMouseInsideTheCannonball(mouseX, mouseY, CANNONBALL_POS_X, CANNONBALL_POS_Y, CANNONBALL_RADIUS)) {
    aimCannonballState = true;
  }

  if (isSettingsWindowActive) {
    if (mouseX >= 438 && mouseX <= 458 && mouseY >= 215 && mouseY <= 235) {
      CANNONBALL_RADIUS--;
      if (int(CANNONBALL_RADIUS) <= 5) {
        CANNONBALL_RADIUS = 5;
      }
    } else if (mouseX >= 550 && mouseX <= 570 && mouseY >= 215 && mouseY <= 235) {
      CANNONBALL_RADIUS++;
      if (int(CANNONBALL_RADIUS) >= 15) {
        CANNONBALL_RADIUS = 15;
      }
    } else if (mouseX >= 494 && mouseX <= 514 && mouseY >= 311 && mouseY <= 331) {
      if (isGuidelineDisabled) {
        isGuidelineDisabled = false;
      } else {
        isGuidelineDisabled = true;
      }
    } else if (mouseX >= 438 && mouseX <= 458 && mouseY >= 247 && mouseY <= 267) {
      CANNONBALL_RADIUS--;
      if (int(CANNONBALL_RADIUS) <= 5) {
        CANNONBALL_RADIUS = 5;
      }
    } else if (mouseX >= 550 && mouseX <= 570 && mouseY >= 247 && mouseY <= 267) {
      CANNONBALL_RADIUS++;
      if (int(CANNONBALL_RADIUS) >= 15) {
        CANNONBALL_RADIUS = 15;
      }
    }
  }
}

void mouseReleased() {
  if (aimCannonballState) {
    isProjectilePathActive = true;
  }
}

void drawAimCannonball(boolean aimBallState) {
  if (aimBallState) {
    float aimCannonballPosX = mouseX;
    float aimCannonballPosY = mouseY;

    if (aimCannonballPosX >= CANNONBALL_POS_X) {
      aimCannonballPosX = CANNONBALL_POS_X - 0.01;
    }
    if (aimCannonballPosY <= CANNONBALL_POS_Y) {
      aimCannonballPosY = CANNONBALL_POS_Y + 0.01;
    }

    float distance = dist(aimCannonballPosX, aimCannonballPosY, CANNONBALL_POS_X, CANNONBALL_POS_Y);
    angle = atan2(aimCannonballPosY - CANNONBALL_POS_Y, aimCannonballPosX - CANNONBALL_POS_X);

    if (distance >= MAXIMUM_VELOCITY) {
      aimCannonballPosX = (CANNONBALL_POS_X - 0.01) + (MAXIMUM_VELOCITY * cos(angle));
      aimCannonballPosY = (CANNONBALL_POS_Y + 0.01) + (MAXIMUM_VELOCITY * sin(angle));
    }

    angle = atan2(aimCannonballPosY - CANNONBALL_POS_Y, aimCannonballPosX - CANNONBALL_POS_X);

    strokeWeight(1);
    fill(#26ECE2);
    stroke(#3472C5);
    ellipse(aimCannonballPosX, aimCannonballPosY, CANNONBALL_RADIUS * 2, CANNONBALL_RADIUS * 2);
    strokeWeight(5);
    if (!isGuidelineDisabled) {
      line(aimCannonballPosX, aimCannonballPosY, CANNONBALL_POS_X, CANNONBALL_POS_Y);
    }
    velocity = getVelocity(aimCannonballPosX, aimCannonballPosY, CANNONBALL_POS_X, CANNONBALL_POS_Y);
  }
}

float getVelocity(float x1, float y1, float x2, float y2) {
  float velocity = dist(x1, y1, x2, y2);

  if (velocity >= MAXIMUM_VELOCITY) {
    velocity = MAXIMUM_VELOCITY;
  }

  return velocity;
}

void drawCannonballAlongProjectilePath(float t) {
  float vX = velocity * cos(angle);
  float vY = velocity * sin(angle);
  float cliffW = CANNONBALL_POS_X;
  float cliffH = CANNONBALL_POS_Y;
  float posX = cliffW - (vX * t);
  float posY = 16 * pow(t, 2) - (vY * t) + cliffH;

  fill(#26ECE2);
  stroke(#080340);
  strokeWeight(1);
  ellipse(posX, posY, CANNONBALL_RADIUS * 2, CANNONBALL_RADIUS * 2);

  if ((posX < 162.5 - CANNONBALL_RADIUS || posX > 492.5 + CANNONBALL_RADIUS) && posY > height + CANNONBALL_RADIUS) {
    isProjectilePathActive = false;
    time = 0;
    isGameOver = true;
    checkToSetHighScore();
  }

  if (posX >= 162.5 - CANNONBALL_RADIUS && posX <= 492.5 + CANNONBALL_RADIUS && posY >= 521.5 - CANNONBALL_RADIUS) {
    isProjectilePathActive = false;
    time = 0;

    if (posX >= desiredTragetPositionX + CANNONBALL_RADIUS && posX <= (desiredTragetPositionX + TARGET_WIDTH) - CANNONBALL_RADIUS) {
      reset();
      score++;
      println(score);
    } else {
      isGameOver = true;
      checkToSetHighScore();
    }
  }
}

void drawSettingsWindow() {
  // background
  stroke(#FF7D5A);
  fill(#9DDBF0);
  rectMode(CENTER);
  rect(centreX, centreY, 488, 245, 2);

  String settings = "Settings";
  String cannonballSize = "Cannonball Size";
  String numberOfTargets = "Number of Targets";
  String difficultyLevel = "Difficulty Level";
  String disableGuideline = "Disable Guideline";

  textFont(montserratBold, 17);
  fill(#080340);
  textAlign(CENTER, CENTER);
  text(settings, 370.5, 187.5);
  textFont(montserratRegular, 17);
  textAlign(LEFT, TOP);
  text(cannonballSize, 169.5, 215);
  text(numberOfTargets, 169.5, 247);
  text(difficultyLevel, 169.5, 279);
  text(disableGuideline, 169.5, 311);

  closeSettingsWindowButton();
  toggleGuideline();
  toggleCursorForSettingsWindow();
  drawCannonballSizeTextAndControls();
}

void closeSettingsWindowButton() {
  if (isSettingsWindowActive) {
    if (mouseX >= 585 && mouseX <= 605 && mouseY >= 159 && mouseY <= 179) {
      image(closeButtonHover, 585, 159);
      if (mousePressed) {
        isMainMenuActive = true;
        isSettingsWindowActive = false;
      }
    } else {
      image(closeButton, 585, 159);
    }
  }
}

void toggleGuideline() {
  if (isSettingsWindowActive) {
    if (mouseX >= 494 && mouseX <= 514 && mouseY >= 311 && mouseY <= 331) {
      if (isGuidelineDisabled) {
        image(checkedCheckboxHover, 494, 311);
      } else {
        image(uncheckedCheckboxHover, 494, 311);
      }
    } else {
      if (isGuidelineDisabled) {
        image(checkedCheckbox, 494, 311);
      } else {
        image(uncheckedCheckbox, 494, 311);
      }
    }
  }
}

void toggleCursorForSettingsWindow() {
  if (mouseX >= 585 && mouseX <= 605 && mouseY >= 159 && mouseY <= 179) {
    cursor(HAND);
  } else if (mouseX >= 494 && mouseX <= 514 && mouseY >= 311 && mouseY <= 331) {
    cursor(HAND);
  } else if (mouseX >= 438 && mouseX <= 458 && mouseY >= 215 && mouseY <= 235) {
    cursor(HAND);
  } else if (mouseX >= 550 && mouseX <= 570 && mouseY >= 215 && mouseY <= 235) {
    cursor(HAND);
  } else if (mouseX >= 438 && mouseX <= 458 && mouseY >= 247 && mouseY <= 267) {
    cursor(HAND);
  } else if (mouseX >= 550 && mouseX <= 570 && mouseY >= 247 && mouseY <= 267) {
    cursor(HAND);
  } else {
    cursor(ARROW);
  }
}

void drawCannonballSizeTextAndControls() {
  fill(#080340);
  textFont(montserratRegular, 17);
  textAlign(LEFT, TOP);
  text(int(CANNONBALL_RADIUS), 499, 215);

  // cannonball size left button
  if (mouseX >= 438 && mouseX <= 458 && mouseY >= 215 && mouseY <= 235) {
    image(leftArrowHover, 438, 215);
  } else {
    image(leftArrow, 438, 215);
  }

  // cannonball size right button
  if (mouseX >= 550 && mouseX <= 570 && mouseY >= 215 && mouseY <= 235) {
    image(rightArrowHover, 550, 215);
  } else {
    image(rightArrow, 550, 215);
  }

  // number of targets left button
  if (mouseX >= 438 && mouseX <= 458 && mouseY >= 247 && mouseY <= 267) {
    image(leftArrowHover, 438, 247);
  } else {
    image(leftArrow, 438, 247);
  }

  // number of targets right button
  if (mouseX >= 550 && mouseX <= 570 && mouseY >= 247 && mouseY <= 267) {
    image(rightArrowHover, 550, 247);
  } else {
    image(rightArrow, 550, 247);
  }
}

void drawInstructionsWindow() {
  // background
  stroke(#FF7D5A);
  fill(#9DDBF0);
  rectMode(CENTER);
  rect(centreX, centreY, 488, 245, 2);

  String instructionText = "Instructions";
  String instructions = "1: To start, move cannonball away.\n" +
    "2: Change angle of projectile within the guides.\n" +
    "3: Change speed of cannonball by pulling away.\n" +
    "4: Release cannonball to fire shot.\n" +
    "5: To win, score more than high score.";

  textFont(montserratBold, 17);
  fill(#080340);
  textAlign(CENTER, CENTER);
  text(instructionText, 370.5, 187.5);
  textFont(montserratRegular, 17);
  textAlign(LEFT, CENTER);
  text(instructions, 169.5, centreY);

  closeInstructionsWindowButton();
}

void closeInstructionsWindowButton() {
  if (isInstructionsWindowActive) {
    if (mouseX >= 585 && mouseX <= 605 && mouseY >= 159 && mouseY <= 179) {
      cursor(HAND);
      image(closeButtonHover, 585, 159);
      if (mousePressed) {
        isMainMenuActive = true;
        isInstructionsWindowActive = false;
      }
    } else {
      image(closeButton, 585, 159);
      cursor(ARROW);
    }
  }
}

void drawCreditWindow() {
  // background
  stroke(#FF7D5A);
  fill(#9DDBF0);
  rectMode(CENTER);
  rect(centreX, centreY, 488, 245, 2);

  String name = "Anas Uddin";
  String credit = "Developed with love by\nAnas Uddin";

  textFont(playlistScript, 24);
  fill(#080340);
  textAlign(CENTER, CENTER);
  text(name, centreX, 187.5);
  image(flower, 420.11, 156.31);
  textFont(montserratRegular, 17);
  text(credit, centreX, centreY);

  closeCreditWindowAndGitHubButton();
}

void closeCreditWindowAndGitHubButton() {
  if (isCreditWindowActive) {
    if (mouseX >= 585 && mouseX <= 605 && mouseY >= 159 && mouseY <= 179) {
      cursor(HAND);
      image(closeButtonHover, 585, 159);
      image(github, 355, 334);
      if (mousePressed) {
        isMainMenuActive = true;
        isCreditWindowActive = false;
      }
    } else if (mouseX >= 355 && mouseX <= 385 && mouseY >= 334 && mouseY <= 364) {
      cursor(HAND);
      image(githubHover, 355, 334);
      image(closeButton, 585, 159);
      if (mousePressed) {
        link("https://github.com/theanasuddin");
      }
    } else {
      image(closeButton, 585, 159);
      image(github, 355, 334);
      cursor(ARROW);
    }
  }
}

void drawCurrentVelocityAndAngle(float velocity, float angle) {
  String angleText;
  String velocityText = "Velocity: " + String.format("%.2f", velocity);
  if (angle == 0) {
    angleText = "Angle: " + String.format("%.2f", angle);
  } else {
    angleText = "Angle: " + String.format("%.2f", 180 - angle);
  }

  textSize(14);
  fill(#3472C5);
  textAlign(BASELINE);
  text(velocityText, 10, height - 26);
  text(angleText, 10, height - 11);
}

void drawExitOptions() {
  String result;
  color textFill;
  if (isWin) {
    result = "You Win!";
    textFill = color(#468847);
  } else {
    result = "You Lost!";
    textFill = color(#350528);
  }

  float posX = centreX;
  float resultTextPosY = centreY - 106;
  float playAgainButtonPosY = centreY;
  float exitButtonPosY = centreY + 106;

  rectMode(CENTER);
  strokeWeight(3);
  textAlign(CENTER, CENTER);
  if (isGameOver) {
    image(menuBackground, 0, 0);

    fill(#26ECE2);
    stroke(#FEAE0D);
    rect(posX, resultTextPosY, 260, 57, 2);
    fill(textFill);
    textSize(17);
    text("Your Score: " + score + ", High Score: " + highScore + "\n" + result, posX, resultTextPosY);

    doExitOrPlayAgain();

    if (playAgainHover) {
      fill(#26ECE2);
      stroke(#FEAE0D);
    } else {
      stroke(#FF7D5A);
      fill(#9DDBF0);
    }
    rect(posX, playAgainButtonPosY, 124, 57, 2);
    fill(#080340);
    text("Play Again", posX, playAgainButtonPosY);

    fill(#26ECE2);
    if (mainMenuButtonHover) {
      fill(#26ECE2);
      stroke(#FEAE0D);
    } else {
      stroke(#FF7D5A);
      fill(#9DDBF0);
    }
    rect(posX, exitButtonPosY, 124, 57, 2);
    fill(#080340);
    text("Main Menu", posX, exitButtonPosY);
  }
}

void doExitOrPlayAgain() {
  if (mouseX >= centreX - 62 && mouseX <= centreX + 62 && mouseY >= 350 && mouseY <= 407) {
    cursor(HAND);
    mainMenuButtonHover = true;
    if (mousePressed) {
      isMainMenuActive = true;
    }
  } else if (mouseX >= centreX - 62 && mouseX <= centreX + 62 && mouseY >= 244 && mouseY <= 301) {
    cursor(HAND);
    playAgainHover = true;
    if (mousePressed) {
      reset();
    }
  } else {
    cursor(ARROW);
    playAgainHover = false;
    mainMenuButtonHover = false;
  }
}

void switchCursor() {
  if (aimCannonballState || isMouseInsideTheCannonball(mouseX, mouseY, CANNONBALL_POS_X, CANNONBALL_POS_Y, CANNONBALL_RADIUS)) {
    if (!isProjectilePathActive) {
      cursor(HAND);
    }
  } else {
    cursor(ARROW);
  }
}

void reset() {
  isGameOver = false;
  velocity = 0;
  angle = 0;
  score = 0;
  desiredTragetIndex = (int)random(0, 10);
  highScore = loadHighScore("high_score.txt");
  isWin = false;
}

void drawCurrentScoreAndHighScore() {
  textSize(21);
  fill(#3472C5);
  textAlign(BASELINE);
  text("High Score: " + highScore, 557.5, 57.5);
  text("Your Score: " + score, 557.5, 80.5);
}

int loadHighScore(String fileName) {
  int highScore = 0;

  try {
    String[] lines = loadStrings(fileName);
    highScore = int(lines[0]);
  }
  catch (Exception e) {
    e.printStackTrace();
  }

  return highScore;
}

void checkToSetHighScore() {
  if (score > highScore) {
    isWin = true;
    try {
      String[] scoreArray = {Integer.toString(score)};
      saveStrings("data/high_score.txt", new String[] {});
      saveStrings("data/high_score.txt", scoreArray);
    }
    catch (Exception e) {
      e.printStackTrace();
    }
  }
}

void drawCannonLogo() {
  rectMode(CENTER);
  fill(#9DDBF0);
  stroke(#FF7D5A);
  strokeWeight(3);
  rect(centreX, centreY, 170, 213.67, 2);

  textFont(montserratBold, 24);
  fill(#080340);
  textAlign(CENTER, CENTER);
  text("CANNON\nCRAZE", 370.5, 335);

  cannonLogo = loadShape("logo.svg");
  shapeMode(CENTER);
  noStroke();
  PShape cannonLogoShape = cannonLogo.getChild("Layer 1");
  cannonLogoShape.disableStyle();
  fill(#080340);
  shape(cannonLogoShape, 370.5, 240.5);
}

void drawMainMenuButtons() {
  doMainMenuButtonsActions();

  strokeWeight(3);
  rectMode(CENTER);
  textAlign(CENTER, CENTER);
  textFont(montserratRegular, 17);

  // play button
  if (playHover) {
    fill(#26ECE2);
    stroke(#FEAE0D);
  } else {
    stroke(#FF7D5A);
    fill(#9DDBF0);
  }
  rect(188.5, 200.5, 124, 57, 2);
  fill(#080340);
  text("Play", 188.5, 200.5);

  // settings button
  if (settingsHover) {
    fill(#26ECE2);
    stroke(#FEAE0D);
  } else {
    stroke(#FF7D5A);
    fill(#9DDBF0);
  }
  rect(188.5, 272.5, 124, 57, 2);
  fill(#080340);
  text("Settings", 188.5, 272.5);

  // help button
  if (helpHover) {
    fill(#26ECE2);
    stroke(#FEAE0D);
  } else {
    stroke(#FF7D5A);
    fill(#9DDBF0);
  }
  rect(188.5, 344.5, 124, 57, 2);
  fill(#080340);
  text("Help", 188.5, 344.5);

  // credit button
  if (creditHover) {
    fill(#26ECE2);
    stroke(#FEAE0D);
  } else {
    stroke(#FF7D5A);
    fill(#9DDBF0);
  }
  rect(552.5, 200.5, 124, 57, 2);
  fill(#080340);
  text("Credit", 552.5, 200.5);

  // exit button
  if (exitHover) {
    fill(#26ECE2);
    stroke(#FEAE0D);
  } else {
    stroke(#FF7D5A);
    fill(#9DDBF0);
  }
  rect(552.5, 272.5, 124, 57, 2);
  fill(#080340);
  text("Exit", 552.5, 272.5);
}

boolean isMouseInsideAButton(float buttonCentreX, float buttonCentreY) {
  if (mouseX >= buttonCentreX - 62 && mouseX <= buttonCentreX + 62 && mouseY >= buttonCentreY - 28.5 && mouseY <= buttonCentreY + 28.5) {
    return true;
  } else {
    return false;
  }
}

void doMainMenuButtonsActions() {
  if (isMouseInsideAButton(188.5, 200.5)) {
    cursor(HAND);
    playHover = true;
    if (mousePressed) {
      startPlaying();
    }
  } else if (isMouseInsideAButton(188.5, 272.5)) {
    cursor(HAND);
    settingsHover = true;
    if (mousePressed) {
      isSettingsWindowActive = true;
    }
  } else if (isMouseInsideAButton(552.5, 272.5)) {
    cursor(HAND);
    exitHover = true;
    if (mousePressed) {
      exit();
    }
  } else if (isMouseInsideAButton(188.5, 344.5)) {
    cursor(HAND);
    helpHover = true;
    if (mousePressed) {
      isInstructionsWindowActive = true;
    }
  } else if (isMouseInsideAButton(552.5, 200.5)) {
    cursor(HAND);
    creditHover = true;
    if (mousePressed) {
      isCreditWindowActive = true;
    }
  } else {
    cursor(ARROW);
    playHover = false;
    settingsHover = false;
    exitHover = false;
    helpHover = false;
    creditHover = false;
  }
}

void startPlaying() {
  isMainMenuActive = false;
  isGameOver = false;
}
