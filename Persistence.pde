// -- Persistence: settings and high score -----------------------------------------

int loadHighScore(String fileName) {
  try {
    String[] lines = loadStrings(fileName);
    if (lines != null && lines.length > 0) return int(lines[0]);
  } catch (Exception e) { /* fall through to default */ }
  return 0;
}

void saveHighScore() {
  try {
    saveStrings("data/high_score.txt", new String[] { str(highScore) });
  } catch (Exception e) {
    e.printStackTrace();
  }
}

// Settings file, one value per line. Older files with fewer lines load fine:
// anything missing keeps its default.
//   1  target count          2  guide hidden flag     3  ball radius
//   4  sound on flag         5  volume (0 to 100)     6  graphics flag (auto | low)
void loadSettings(String fileName) {
  try {
    String[] lines = loadStrings(fileName);
    if (lines == null) return;
    if (lines.length >= 1) targetCount     = constrain(int(lines[0]), TARGETS_MIN, TARGETS_MAX);
    if (lines.length >= 2) guidelineHidden = "true".equals(lines[1]);
    if (lines.length >= 3) ballRadius      = constrain(int(lines[2]), BALL_RADIUS_MIN, BALL_RADIUS_MAX);
    if (lines.length >= 4) soundOn         = !"false".equals(lines[3]);
    if (lines.length >= 5) soundVolume     = constrain(int(lines[4]), 0, 100) / 100.0;
    if (lines.length >= 6) lowGfxSaved     = "low".equals(trim(lines[5]));
  } catch (Exception e) { /* keep defaults */ }
}

void saveSettings(String fileName) {
  try {
    saveStrings("data/" + fileName, new String[] {
      str(targetCount),
      guidelineHidden ? "true" : "false",
      str(int(ballRadius)),
      soundOn ? "true" : "false",
      str(round(soundVolume * 100)),
      lowGfxSaved ? "low" : "auto"
    });
  } catch (Exception e) {
    e.printStackTrace();
  }
}

// Reads only the graphics flag (line 6), safe to call from settings() before
// Processing's file helpers are available. Returns "auto" when in doubt.
String peekGfxFlag() {
  java.io.BufferedReader r = null;
  try {
    java.io.File f = new java.io.File(sketchPath("data"), "settings.txt");
    if (!f.isFile()) return "auto";
    r = new java.io.BufferedReader(new java.io.FileReader(f));
    String line = null;
    for (int i = 0; i < 6; i++) {
      line = r.readLine();
      if (line == null) return "auto";
    }
    return "low".equals(line.trim()) ? "low" : "auto";
  } catch (Exception e) {
    return "auto";
  } finally {
    try { if (r != null) r.close(); } catch (Exception e) { }
  }
}
