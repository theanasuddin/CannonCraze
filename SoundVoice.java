// -- SoundVoice: one pre-opened audio output line on its own daemon thread -------
// Lives in a .java tab because the sketch preprocessor cannot parse the
// line.open(...) call. Each voice owns a SourceDataLine and drains a queue of
// PCM chunks; the pool in Sound.pde round-robins across voices so effects
// overlap freely.

import javax.sound.sampled.AudioFormat;
import javax.sound.sampled.AudioSystem;
import javax.sound.sampled.SourceDataLine;
import java.util.concurrent.LinkedBlockingQueue;

public class SoundVoice extends Thread {
  public final LinkedBlockingQueue<byte[]> queue = new LinkedBlockingQueue<byte[]>();
  public boolean ok = false;
  private SourceDataLine out;

  public SoundVoice(AudioFormat fmt) {
    try {
      out = AudioSystem.getSourceDataLine(fmt);
      out.open(fmt, 8192);
      out.start();
      ok = true;
      setDaemon(true);
      setName("CannonCraze-sound");
      start();
    } catch (Exception e) {
      ok = false;
    }
  }

  @Override
  public void run() {
    try {
      while (true) {
        byte[] pcm = queue.take();
        out.write(pcm, 0, pcm.length);
        out.drain();
      }
    } catch (InterruptedException e) {
      // sketch is shutting down
    }
  }
}
