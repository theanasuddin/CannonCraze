// -- Viewport: a resizable window filled edge to edge ----------------------------
// The game is designed on a 960 x 600 canvas. The window can be resized or
// maximized freely: each frame the canvas scales uniformly to the largest size
// that fits, and instead of letterboxing the leftover space, the world itself
// extends past the design region (more sky, wider mountains, longer ground) so
// the scene always fills the entire window. Gameplay geometry stays fixed and
// centred, so the game plays identically at every window size, and because the
// whole scene is procedural it stays crisp at any scale.

final int VIEW_W = 960;
final int VIEW_H = 600;

float viewS  = 1;        // window to canvas scale (uniform)
float offX   = 0;        // how far the world extends past the design region,
float offY   = 0;        // per side, in canvas units
float worldW = VIEW_W;   // full window size in canvas units
float worldH = VIEW_H;
float vmx    = 0;        // mouse position in canvas coordinates
float vmy    = 0;

void initViewport() {
  surface.setResizable(true);
  try {
    processing.awt.PSurfaceAWT.SmoothCanvas canvas =
      (processing.awt.PSurfaceAWT.SmoothCanvas) surface.getNative();
    canvas.getFrame().setMinimumSize(new java.awt.Dimension(VIEW_W / 2, VIEW_H / 2));
  } catch (Exception e) {
    // Unknown surface implementation: resizing still works, only the size floor is lost.
  }
}

void updateViewport() {
  viewS = min(width / (float) VIEW_W, height / (float) VIEW_H);
  if (viewS <= 0) viewS = 1;
  worldW = width  / viewS;
  worldH = height / viewS;
  offX   = (worldW - VIEW_W) / 2;
  offY   = (worldH - VIEW_H) / 2;
  if (width != bgSceneW || height != bgSceneH) rebuildBackground();
  syncCanvasMouse();
}

// World edges in canvas coordinates: the design region spans 0..VIEW_W and
// 0..VIEW_H, the visible world reaches these bounds.
float worldLeft()   { return -offX; }
float worldRight()  { return VIEW_W + offX; }
float worldTop()    { return -offY; }
float worldBottom() { return VIEW_H + offY; }

// Also called from mouse handlers, so clicks are mapped with current geometry
// even when they land between frames.
void syncCanvasMouse() {
  vmx = mouseX / viewS - offX;
  vmy = mouseY / viewS - offY;
}

void beginViewport() {
  // The static scene buffer is exactly window-sized, so it blits 1:1 in screen
  // space before the world transform. That keeps Java2D on its fast copy path
  // (a scaled blit interpolates every pixel and tanks the frame rate on large
  // windows) and doubles as the background clear.
  if (bgScene != null) image(bgScene, 0, 0);
  else                 background(SKY_TOP);
  pushMatrix();
  scale(viewS);
  translate(offX, offY);
}

void endViewport() {
  popMatrix();
}
