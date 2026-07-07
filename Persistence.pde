// ── Persistence — settings and high score ──────────────────────────────────────

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

void loadSettings(String fileName) {
  try {
    String[] lines = loadStrings(fileName);
    if (lines == null) return;
    if (lines.length >= 1) targetCount     = constrain(int(lines[0]), TARGETS_MIN, TARGETS_MAX);
    if (lines.length >= 2) guidelineHidden = "true".equals(lines[1]);
    if (lines.length >= 3) ballRadius      = constrain(int(lines[2]), BALL_RADIUS_MIN, BALL_RADIUS_MAX);
  } catch (Exception e) { /* keep defaults */ }
}

void saveSettings(String fileName) {
  try {
    saveStrings("data/" + fileName, new String[] {
      str(targetCount),
      guidelineHidden ? "true" : "false",
      str(int(ballRadius))
    });
  } catch (Exception e) {
    e.printStackTrace();
  }
}
