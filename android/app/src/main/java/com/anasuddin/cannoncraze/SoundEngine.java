package com.anasuddin.cannoncraze;

import android.media.AudioAttributes;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.os.Build;

import java.util.ArrayList;

/**
 * A tiny software mixer over one streaming AudioTrack.
 *
 * The game synthesizes every effect at startup as 16-bit 44.1 kHz PCM
 * (there are no audio asset files). Effects are handed to {@link #play}
 * with a per-shot amplitude; the mixer thread sums the active voices into
 * a small buffer and streams it out, so any number of effects can overlap
 * with consistent low latency. If the device refuses an AudioTrack the
 * engine disables itself and every call becomes a silent no-op.
 */
final class SoundEngine {
  private static final int RATE = 44100;
  private static final int MIX_FRAMES = 512;
  private static final int MAX_VOICES = 16;

  private static final class Voice {
    short[] samples;
    int pos;
    float amp;
  }

  private final ArrayList<Voice> voices = new ArrayList<>();
  private AudioTrack track;
  private Thread mixer;
  private volatile boolean running = false;
  private volatile boolean active = true;   // false while the app is paused
  public boolean available = false;

  SoundEngine() {
    try {
      int minBuf = AudioTrack.getMinBufferSize(RATE,
          AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT);
      int bufBytes = Math.max(minBuf, MIX_FRAMES * 2 * 4);

      if (Build.VERSION.SDK_INT >= 26) {
        track = new AudioTrack.Builder()
            .setAudioAttributes(new AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build())
            .setAudioFormat(new AudioFormat.Builder()
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setSampleRate(RATE)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                .build())
            .setBufferSizeInBytes(bufBytes)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
            .build();
      } else {
        track = new AudioTrack(AudioManager.STREAM_MUSIC, RATE,
            AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT,
            bufBytes, AudioTrack.MODE_STREAM);
      }

      track.play();
      running = true;
      available = true;

      mixer = new Thread(this::mixLoop, "CannonCraze-sound");
      mixer.setDaemon(true);
      mixer.start();
    } catch (Exception e) {
      available = false;
      release();
    }
  }

  /** Queue an effect. amp is the final linear amplitude for this shot (0..1). */
  void play(short[] samples, float amp) {
    if (!available || samples == null || amp <= 0.0005f) return;
    Voice v = new Voice();
    v.samples = samples;
    v.pos = 0;
    v.amp = amp;
    synchronized (voices) {
      if (voices.size() < MAX_VOICES) voices.add(v);
      voices.notifyAll();   // wake the mixer if it is idling
    }
  }

  /** Pause mixing while the app is in the background. */
  void setActive(boolean on) {
    active = on;
    if (track == null) return;
    try {
      if (on) {
        track.play();
        synchronized (voices) { voices.notifyAll(); }
      } else {
        track.pause();
        track.flush();
        synchronized (voices) { voices.clear(); }
      }
    } catch (IllegalStateException ignored) { }
  }

  void release() {
    running = false;
    synchronized (voices) { voices.notifyAll(); }
    if (mixer != null) mixer.interrupt();
    if (track != null) {
      try { track.release(); } catch (Exception ignored) { }
      track = null;
    }
  }

  private void mixLoop() {
    int[] mix = new int[MIX_FRAMES];
    short[] outBuf = new short[MIX_FRAMES];
    int silentRuns = 0;   // consecutive buffers mixed with no active voice

    while (running) {
      // Idle: after ~a third of a second of pure silence, park the thread
      // instead of streaming zeros forever. On low-end phones the always-on
      // write loop is measurable CPU and battery; parked, it costs nothing
      // until the next effect (or resume) notifies.
      boolean parked = false;
      synchronized (voices) {
        if (!active || (voices.isEmpty() && silentRuns >= 30)) {
          parked = true;
          try { track.pause(); } catch (Exception ignored) { }
          while (running && (!active || voices.isEmpty())) {
            try { voices.wait(500); } catch (InterruptedException e) { return; }
          }
          silentRuns = 0;
        }
      }
      if (!running) return;
      if (parked) {
        try { track.play(); } catch (Exception e) { return; }
      }

      java.util.Arrays.fill(mix, 0);
      boolean mixedAny = false;
      synchronized (voices) {
        for (int i = voices.size() - 1; i >= 0; i--) {
          Voice v = voices.get(i);
          int n = Math.min(MIX_FRAMES, v.samples.length - v.pos);
          for (int j = 0; j < n; j++) {
            mix[j] += (int) (v.samples[v.pos + j] * v.amp);
          }
          v.pos += n;
          mixedAny = true;
          if (v.pos >= v.samples.length) voices.remove(i);
        }
      }
      silentRuns = mixedAny ? 0 : silentRuns + 1;

      for (int j = 0; j < MIX_FRAMES; j++) {
        int s = mix[j];
        if (s > 32767) s = 32767;
        else if (s < -32768) s = -32768;
        outBuf[j] = (short) s;
      }

      try {
        track.write(outBuf, 0, MIX_FRAMES);   // blocks, paces the loop
      } catch (Exception e) {
        return;
      }
    }
  }
}
