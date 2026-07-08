// -- CannonCrazeGraphics: the stock JAVA2D renderer plus one resize fix ----------
// Live-resizing an AWT window can race the JDK's BltBufferStrategy: the buffers
// are invalidated mid-frame and strategy.show() throws a NullPointerException
// ("this.backBuffers[i] is null"), which kills Processing's animation thread and
// freezes the sketch. The frame that hits the race is already stale, so the
// correct handling is to skip presenting it and let the next frame draw normally.

public class CannonCrazeGraphics extends processing.awt.PGraphicsJava2D {

  @Override
  public processing.core.PSurface createSurface() {
    return new processing.awt.PSurfaceAWT(this) {
      @Override
      protected void render() {
        try {
          super.render();
        } catch (NullPointerException e) {
          // Transient AWT back-buffer race during a live resize: drop the frame.
        }
      }
    };
  }
}
