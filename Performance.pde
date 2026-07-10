// -- Performance: real-time clock + adaptive quality governor ---------------------
// Two jobs, both in service of "plays the same on every machine":
//
//   1. The clock measures the real time between frames. All motion (flight,
//      particles, easing, timers) advances by that delta, so on a machine that
//      only manages 40 fps the game drops frames instead of running in slow
//      motion, and on a fast display it never fast-forwards.
//
//   2. The governor watches the smoothed frame rate and steps the visual
//      quality tier down (or back up) so weak GPUs spend their budget on the
//      gameplay, not the garnish. Tiers only touch decoration: star count,
//      glow passes, light-column slices, particle counts. Gameplay geometry,
//      physics, and difficulty are identical at every tier.
//
// On top of that, if a HiDPI machine stays pinned at the lowest tier, a
// low-graphics flag is saved with the settings and the next launch renders at
// 1x density, which is the single biggest lever Java2D has. The flag clears
// itself the same way if the machine later proves comfortable.

// -- Clock ------------------------------------------------------------------------

float dtSec = 1 / 60.0;   // real seconds since the previous frame, clamped
float nf    = 1;          // normalized frames: dtSec * 60 (1.0 at exactly 60 fps)
long  lastFrameMs = -1;
float fpsAvg = 60;        // exponentially smoothed fps for the governor

void updateClock() {
  long now = millis();
  if (lastFrameMs < 0) lastFrameMs = now - 16;
  float raw = (now - lastFrameMs) / 1000.0;
  lastFrameMs = now;
  if (raw > 0.0001) fpsAvg = lerp(fpsAvg, min(1.0 / raw, 240), 0.06);
  dtSec = constrain(raw, 1 / 240.0, 1 / 20.0);
  nf    = dtSec * 60;
}

// Converts a per-frame lerp factor (tuned at 60 fps) into its frame-rate
// independent equivalent, so easing settles in the same wall-clock time
// everywhere.
float expK(float k) {
  return 1 - pow(1 - k, nf);
}

// -- Quality tiers ------------------------------------------------------------------

final int GFX_LOW  = 0;
final int GFX_MED  = 1;
final int GFX_HIGH = 2;

int     gfxTier    = GFX_HIGH;
int     gfxTierMax = GFX_HIGH;   // capped when a raise immediately falls back
boolean lastChangeWasRaise = false;
float   tierHoldT  = 0;          // seconds since the tier last changed
float   raiseOkT   = 0;          // continuous seconds of comfortable fps
float   pinnedLowT = 0;          // continuous seconds pinned at LOW (density flag)

boolean lowGfxSaved = false;     // "gfx" line in settings.txt: render at 1x density

void updatePerfGovernor() {
  tierHoldT += dtSec;
  if (millis() < 2500) return;   // ignore startup jank while caches warm

  if (fpsAvg > 57) raiseOkT += dtSec;
  else             raiseOkT = 0;

  if (fpsAvg < 48 && gfxTier > GFX_LOW && tierHoldT > 2) {
    // A drop right after a raise means the higher tier does not fit: stop
    // offering it, otherwise the tiers oscillate.
    if (lastChangeWasRaise && tierHoldT < 12) gfxTierMax = gfxTier - 1;
    gfxTier--;
    lastChangeWasRaise = false;
    tierHoldT = 0;
  } else if (raiseOkT > 6 && gfxTier < gfxTierMax) {
    gfxTier++;
    lastChangeWasRaise = true;
    tierHoldT = 0;
    raiseOkT  = 0;
  }

  updateDensityFlag();
}

// A HiDPI window that cannot climb out of LOW is rendering 4x the pixels the
// machine can afford: remember that, and the next launch opens at 1x density.
// The flag heals in both directions, so plugging into a faster machine (or
// GPU driver fix) eventually restores full density.
void updateDensityFlag() {
  boolean pinned = (gfxTier == GFX_LOW && gfxTierMax == GFX_LOW);
  pinnedLowT = pinned ? pinnedLowT + dtSec : 0;

  if (!lowGfxSaved && pixelDensity > 1 && pinnedLowT > 15) {
    lowGfxSaved = true;
    saveSettings("settings.txt");
  } else if (lowGfxSaved && pixelDensity == 1
             && gfxTier == GFX_HIGH && gfxTierMax == GFX_HIGH && raiseOkT > 30) {
    lowGfxSaved = false;
    saveSettings("settings.txt");
  }
}

// -- Quality knobs -------------------------------------------------------------------
// Everything below is decoration only; gameplay never reads these.

float qStarFrac()     { return gfxTier == GFX_HIGH ? 1.0 : (gfxTier == GFX_MED ? 0.55 : 0.3); }
boolean qSparkles()   { return gfxTier == GFX_HIGH; }
boolean qMeteor()     { return gfxTier != GFX_LOW; }
int   qGlowPasses()   { return gfxTier == GFX_HIGH ? 4 : (gfxTier == GFX_MED ? 2 : 1); }
int   qLinePasses()   { return gfxTier == GFX_HIGH ? 3 : (gfxTier == GFX_MED ? 2 : 1); }
int   qColumnSlices() { return gfxTier == GFX_HIGH ? 30 : (gfxTier == GFX_MED ? 16 : 8); }
float qBurstFrac()    { return gfxTier == GFX_HIGH ? 1.0 : (gfxTier == GFX_MED ? 0.7 : 0.5); }
int   qTrailEvery()   { return gfxTier == GFX_LOW ? 2 : 1; }
