// -- Particles: sparks, trails, shockwave rings, floating score text -----------

final int P_SPARK = 0;
final int P_TRAIL = 1;
final int P_RING  = 2;
final int P_TEXT  = 3;

ArrayList<Particle> particles;

class Particle {
  int    kind;
  float  x, y, vx, vy;
  float  age = 0, life, size;
  color  col;
  String txt;

  Particle(int kind, float x, float y, float vx, float vy, float life, float size, color col) {
    this.kind = kind;
    this.x = x;  this.y = y;  this.vx = vx;  this.vy = vy;
    this.life = life;  this.size = size;  this.col = col;
  }
}

void initParticles() {
  particles = new ArrayList<Particle>();
}

void clearParticles() {
  particles.clear();
}

void spawnBurst(float x, float y, color c, int n, float speed) {
  int count = max(1, round(n * qBurstFrac()));
  for (int i = 0; i < count; i++) {
    float a = random(TWO_PI);
    float s = random(0.4, 1.0) * speed;
    particles.add(new Particle(P_SPARK, x, y, cos(a) * s, sin(a) * s - 1,
                               random(0.4, 0.9), random(2, 4.5), c));
  }
}

void spawnRecordBurst(float x, float y) {
  int count = round(46 * qBurstFrac());
  for (int i = 0; i < count; i++) {
    float a = random(TWO_PI);
    float s = random(1.2, 4.6);
    color c = (i % 2 == 0) ? GOLD : ACCENT;
    particles.add(new Particle(P_SPARK, x, y, cos(a) * s, sin(a) * s - 2,
                               random(0.7, 1.4), random(2.5, 5), c));
  }
}

int trailTick = 0;

void spawnTrail(float x, float y, float size) {
  if (++trailTick % qTrailEvery() != 0) return;   // thinner comet tail on LOW
  particles.add(new Particle(P_TRAIL, x, y, 0, 0, 0.45, size, ACCENT));
}

void spawnRing(float x, float y, color c) {
  particles.add(new Particle(P_RING, x, y, 0, 0, 0.55, 78, c));
}

void spawnScoreFloat(float x, float y) {
  Particle p = new Particle(P_TEXT, x, y, 0, -0.9, 0.9, 15, ACCENT_SOFT);
  p.txt = "+1";
  particles.add(p);
}

void updateParticles() {
  pushStyle();
  for (int i = particles.size() - 1; i >= 0; i--) {
    Particle p = particles.get(i);
    p.age += dtSec;
    float u = p.age / p.life;
    if (u >= 1) {
      particles.remove(i);
      continue;
    }

    if (p.kind == P_SPARK) {
      p.vy += 0.13 * nf;
      p.x  += p.vx * nf;
      p.y  += p.vy * nf;
      noStroke();
      fill(p.col, 235 * (1 - u));
      circle(p.x, p.y, p.size * (1 - u * 0.55));
    } else if (p.kind == P_TRAIL) {
      noStroke();
      fill(p.col, 80 * (1 - u));
      circle(p.x, p.y, p.size * 2 * (1 - u));
    } else if (p.kind == P_RING) {
      noFill();
      stroke(p.col, 210 * (1 - u));
      strokeWeight(2.2 * (1 - u) + 0.4);
      circle(p.x, p.y, p.size * easeOutCubic(u));
    } else {
      p.y += p.vy * nf;
      noStroke();
      textAlign(CENTER, CENTER);
      textFont(fontBold, p.size);
      fill(p.col, 255 * (1 - u));
      text(p.txt, p.x, p.y);
    }
  }
  popStyle();
}
