// -- Sound: procedurally synthesized sound effects -------------------------------
// Every sound is generated at startup as 16-bit 44.1 kHz mono PCM. There are no
// audio asset files, matching the fully procedural visuals. Playback runs on a
// small pool of pre-opened output lines so effects can overlap freely with
// near-zero latency. If the machine has no audio device the engine disables
// itself and every call becomes a silent no-op.

import javax.sound.sampled.AudioFormat;

final int SND_RATE   = 44100;
final int SND_VOICES = 8;

boolean sndAvailable = false;

// Pre-rendered effects (raw samples at full amplitude; volume applies at play time)
short[]   sndLaunch, sndGameOver, sndRecord, sndClick, sndToggle, sndGrab, sndTick;
short[][] sndHit = new short[8][];   // score chime ladder: pitch rises with the run

SoundVoice[] sndVoicePool;
int sndNextVoice = 0;

void initSound() {
  buildAllSounds();
  AudioFormat fmt = new AudioFormat(SND_RATE, 16, 1, true, false);
  sndVoicePool = new SoundVoice[SND_VOICES];
  sndAvailable = true;
  for (int i = 0; i < SND_VOICES; i++) {
    sndVoicePool[i] = new SoundVoice(fmt);
    if (!sndVoicePool[i].ok) {
      sndAvailable = false;   // no audio device: the game simply plays silent
      return;
    }
  }
}

// Scales the pre-rendered samples by the master volume and hands the bytes to
// the next voice in the pool. Perceptual volume: amplitude = volume squared.
void playSound(short[] samples) {
  if (!sndAvailable || !soundOn || samples == null) return;
  float amp = soundVolume * soundVolume;
  if (amp <= 0.0005) return;

  byte[] pcm = new byte[samples.length * 2];
  for (int i = 0; i < samples.length; i++) {
    int v = (int) (samples[i] * amp);
    pcm[i * 2]     = (byte) (v & 0xFF);
    pcm[i * 2 + 1] = (byte) ((v >> 8) & 0xFF);
  }

  SoundVoice voice = sndVoicePool[sndNextVoice];
  sndNextVoice = (sndNextVoice + 1) % SND_VOICES;
  if (voice.queue.size() < 2) voice.queue.offer(pcm);
}

// -- Game-facing triggers ---------------------------------------------------------

void sfxLaunch()          { playSound(sndLaunch); }
void sfxHit(int runScore) { playSound(sndHit[constrain(runScore - 1, 0, sndHit.length - 1)]); }
void sfxGameOver()        { playSound(sndGameOver); }
void sfxRecord()          { playSound(sndRecord); }
void sfxClick()           { playSound(sndClick); }
void sfxToggle()          { playSound(sndToggle); }
void sfxGrab()            { playSound(sndGrab); }
void sfxTick()            { playSound(sndTick); }

// -- Synthesis --------------------------------------------------------------------

void buildAllSounds() {
  sndLaunch   = buildLaunch();
  sndGameOver = buildGameOver();
  sndRecord   = buildRecord();
  sndClick    = buildBlip(1850, 0.055, 90,  0.42);
  sndToggle   = buildBlip(1250, 0.060, 70,  0.42);
  sndTick     = buildBlip(2300, 0.030, 160, 0.30);
  sndGrab     = buildGrab();

  // Major pentatonic ladder starting at C5: every hit in a run sounds one step
  // brighter than the last, capping at the top of the ladder.
  float[] ladder = { 523.25, 587.33, 659.26, 783.99, 880.00, 1046.50, 1174.66, 1318.51 };
  for (int i = 0; i < ladder.length; i++) sndHit[i] = buildChime(ladder[i]);
}

// Cannon shot: a fast downward sine sweep for the body of the thump plus a
// burst of low-passed noise for the muzzle blast, run through a soft clipper.
short[] buildLaunch() {
  int n = (int) (SND_RATE * 0.32);
  float[] b = new float[n];
  float phase = 0, lp = 0;
  for (int i = 0; i < n; i++) {
    float t = i / (float) SND_RATE;
    float u = i / (float) n;
    float f = lerp(155, 42, sqrt(u));
    phase += TWO_PI * f / SND_RATE;
    float body  = sin(phase) * exp(-t * 9);
    float noise = random(-1, 1) * exp(-t * 55);
    lp += (noise - lp) * 0.16;
    b[i] = (float) Math.tanh((body * 0.95 + lp * 1.5) * 1.7) * 0.95;
  }
  return toPcm(b, 0.95);
}

// Score chime: a bright bell of three partials with a hint of detune shimmer.
short[] buildChime(float f) {
  int n = (int) (SND_RATE * 0.55);
  float[] b = new float[n];
  for (int i = 0; i < n; i++) {
    float t = i / (float) SND_RATE;
    float x = sin(TWO_PI * f * t)          * exp(-t * 6.5)
            + sin(TWO_PI * f * 1.006 * t)  * exp(-t * 6.5) * 0.30
            + sin(TWO_PI * f * 2.002 * t)  * exp(-t * 9.0) * 0.50
            + sin(TWO_PI * f * 2.997 * t)  * exp(-t * 13 ) * 0.18;
    b[i] = x * min(1, t / 0.002) * 0.42;
  }
  return toPcm(b, 0.9);
}

// Run over: a falling tone with a dull thud, sad but quick so retries stay snappy.
short[] buildGameOver() {
  int n = (int) (SND_RATE * 0.6);
  float[] b = new float[n];
  float phase = 0, lp = 0;
  for (int i = 0; i < n; i++) {
    float t = i / (float) SND_RATE;
    float u = i / (float) n;
    float f = lerp(196, 68, u * u * (3 - 2 * u));
    phase += TWO_PI * f / SND_RATE;
    float tone  = (sin(phase) + 0.35 * sin(phase * 2 + 0.6)) * exp(-t * 5.5);
    float noise = random(-1, 1) * exp(-t * 34);
    lp += (noise - lp) * 0.12;
    b[i] = (float) Math.tanh((tone * 0.8 + lp * 1.1) * 1.5) * 0.9;
  }
  return toPcm(b, 0.9);
}

// New record: a four-note rising arpeggio of the same bell voice as the chime.
short[] buildRecord() {
  float[] notes  = { 523.25, 659.26, 783.99, 1046.50 };
  float[] onsets = { 0.00, 0.10, 0.20, 0.30 };
  int n = (int) (SND_RATE * 1.15);
  float[] b = new float[n];
  for (int k = 0; k < notes.length; k++) {
    boolean last  = (k == notes.length - 1);
    float   decay = last ? 3.5 : 7.0;
    float   gain  = last ? 0.42 : 0.32;
    int start = (int) (onsets[k] * SND_RATE);
    for (int i = start; i < n; i++) {
      float t = (i - start) / (float) SND_RATE;
      float x = sin(TWO_PI * notes[k] * t)         * exp(-t * decay)
              + sin(TWO_PI * notes[k] * 2.003 * t) * exp(-t * (decay + 3)) * 0.45;
      b[i] += x * min(1, t / 0.002) * gain;
    }
  }
  return toPcm(b, 0.9);
}

// UI blip: one clean sine ping with a whisper of noise on the attack.
short[] buildBlip(float f, float dur, float decay, float gain) {
  int n = (int) (SND_RATE * dur);
  float[] b = new float[n];
  for (int i = 0; i < n; i++) {
    float t = i / (float) SND_RATE;
    float x = sin(TWO_PI * f * t) * exp(-t * decay)
            + random(-1, 1) * exp(-t * 420) * 0.20;
    b[i] = x * min(1, t / 0.001) * gain;
  }
  return toPcm(b, 0.9);
}

// Picking up the cannonball: a tiny rising pluck, quiet by design.
short[] buildGrab() {
  int n = (int) (SND_RATE * 0.09);
  float[] b = new float[n];
  float phase = 0;
  for (int i = 0; i < n; i++) {
    float t = i / (float) SND_RATE;
    float u = i / (float) n;
    phase += TWO_PI * lerp(290, 430, u) / SND_RATE;
    b[i] = sin(phase) * exp(-t * 28) * min(1, t / 0.002) * 0.30;
  }
  return toPcm(b, 0.9);
}

short[] toPcm(float[] b, float amp) {
  short[] out = new short[b.length];
  for (int i = 0; i < b.length; i++) {
    out[i] = (short) (constrain(b[i] * amp, -1, 1) * 32767);
  }
  return out;
}
