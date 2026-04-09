/**
 * BUGGY SPEED PROFILE CHALLENGE — DISPLAY GUI (WiFi receive only)
 * Processing 4.x  —  requires the Network library (Sketch > Import Library > Network)
 *
 * Receives from Arduino:
 *   "D,<time_ms>,<actual_speed_cm_s>\n"   — live data sample
 *   "MSE:<value>\n"                        — final MSE from Arduino
 *   "DONE\n"                               — run complete
 *
 * This GUI does NOT send any commands. Connect to the Arduino's WiFi
 * access point (SSID "Gotham", password "Bruce_Wayne"), click CONNECT,
 * then click START DISPLAY when the buggy run begins.
 *
 * Arduino IP is printed to its Serial Monitor on boot — set it below.
 */

import processing.net.*;

// ─── WiFi TARGET ─────────────────────────────────────────────────────────────
String ARDUINO_IP   = "192.168.4.1";
int    ARDUINO_PORT = 5200;

// ─── PALETTE ─────────────────────────────────────────────────────────────────
color BG         = #0D0F14;
color PANEL      = #13161E;
color BORDER     = #222630;
color ACCENT     = #00E5FF;
color ACTUAL_COL = #FF4D6A;
color GRID_COL   = #1C2030;
color TEXT_COL   = #C8D0E0;
color DIM_COL    = #4A5270;
color OK_COL     = #39FF8A;
color WARN_COL   = #FFB800;

// ─── LAYOUT ──────────────────────────────────────────────────────────────────
int W = 1100, H = 680;
int CX = 50,  CY = 60,  CW = 750, CH = 430;  // chart takes more width now
int PX = 840, PW = 230, PH = H - 40;

// ─── SPEED PROFILE (read-only reference for chart drawing) ───────────────────
int   PROFILE_SIZE = 5;
int[] profTime  = {  0, 10, 30, 45, 55 };
int[] profSpeed = { 10, 20, 25, 10, 0 };

// ─── LIVE DATA ───────────────────────────────────────────────────────────────
int     MAX_SAMPLES = 6000;
float[] tSamples   = new float[MAX_SAMPLES];
float[] refSamples = new float[MAX_SAMPLES];
float[] actSamples = new float[MAX_SAMPLES];
int     sampleCount = 0;

float currentRef    = 0;
float currentActual = 0;
float mseValue      = -1;

boolean running  = false;
boolean finished = false;
float   runStart = 0;
float   elapsed  = 0;

// ─── WiFi ────────────────────────────────────────────────────────────────────
Client  wifi          = null;
boolean wifiConnected = false;
String  wifiStatus    = "Not connected";
String  wifiBuffer    = "";

// ─── FONTS / ANIMATION ───────────────────────────────────────────────────────
PFont monoFont, labelFont, bigFont;
float scanLine = 0;

// ─────────────────────────────────────────────────────────────────────────────
void setup() {
  size(1100, 680);
  smooth(4);
  monoFont  = createFont("Courier New", 13, true);
  labelFont = createFont("Courier New", 11, true);
  bigFont   = createFont("Courier New", 28, true);
  frameRate(60);
}

// ─────────────────────────────────────────────────────────────────────────────
void draw() {
  background(BG);

  // Scan-line atmosphere
  scanLine = (scanLine + 0.4) % H;
  noStroke();
  fill(ACCENT, 6);
  rect(0, scanLine, W, 2);

  // Advance local timer (stopRun() is also triggered by "DONE" from Arduino)
  if (running && !finished) {
    elapsed = (millis() - runStart) / 1000.0;
    if (elapsed >= 60) { elapsed = 60; stopRun(); }
  }

  readWifi();

  drawHeader();
  drawChart();
  drawSidePanel();
  drawStatusBar();
}

// ─── WiFi READ ───────────────────────────────────────────────────────────────
void readWifi() {
  if (!wifiConnected || wifi == null) return;

  if (!wifi.active()) {
    wifiConnected = false;
    wifiStatus    = "Connection lost";
    wifi          = null;
    return;
  }

  while (wifi.available() > 0) {
    char c = (char) wifi.read();
    if (c == '\n') {
      processLine(wifiBuffer.trim());
      wifiBuffer = "";
    } else {
      wifiBuffer += c;
    }
  }
}

void processLine(String line) {
  if (line.length() == 0) return;

  // Run finished
  if (line.equals("DONE")) {
    stopRun();
    return;
  }

  // Arduino-reported MSE: "MSE:906.27"
  if (line.startsWith("MSE:")) {
    mseValue = float(line.substring(4));
    return;
  }

  // Live sample: "D,<time_ms>,<actual_speed>"
  if (line.startsWith("D,")) {
    // Auto-start display when first data arrives (if user forgot to click START)
    if (!running && !finished) startDisplay();

    String[] parts = split(line, ',');
    if (parts.length >= 3) {
      float t   = float(parts[1]) / 1000.0;   // ms → s
      float act = float(parts[2]);
      float ref = refAtTime(t);
      currentRef    = ref;
      currentActual = act;
      elapsed       = t;                       // keep GUI time in sync with Arduino
      if (sampleCount < MAX_SAMPLES) {
        tSamples[sampleCount]   = t;
        refSamples[sampleCount] = ref;
        actSamples[sampleCount] = act;
        sampleCount++;
      }
    }
  }
}

// ─── WiFi CONNECT / DISCONNECT ───────────────────────────────────────────────
void toggleWifi() {
  if (wifiConnected) {
    wifi.stop();
    wifi          = null;
    wifiConnected = false;
    wifiStatus    = "Disconnected";
  } else {
    try {
      wifi = new Client(this, ARDUINO_IP, ARDUINO_PORT);
      if (wifi.active()) {
        wifiConnected = true;
        wifiStatus    = "Connected: " + ARDUINO_IP;
        wifiBuffer    = "";
      } else {
        wifi       = null;
        wifiStatus = "Failed — check IP & network";
      }
    } catch (Exception e) {
      wifi       = null;
      wifiStatus = "Error: " + e.getMessage();
    }
  }
}

// ─── DISPLAY CONTROL ─────────────────────────────────────────────────────────
// startDisplay() only resets the local display — it sends nothing to Arduino
void startDisplay() {
  sampleCount   = 0;
  mseValue      = -1;
  currentRef    = 0;
  currentActual = 0;
  elapsed       = 0;
  running       = true;
  finished      = false;
  runStart      = millis();

}

void stopRun() {
  running  = false;
  finished = true;
  if (mseValue < 0) computeMSE();   // local MSE fallback if Arduino didn't send one
}

// ─── MSE (local fallback) ─────────────────────────────────────────────────────
void computeMSE() {
  if (sampleCount == 0) { mseValue = 0; return; }
  float sum = 0;
  for (int i = 0; i < sampleCount; i++) {
    float e = refSamples[i] - actSamples[i];
    sum += e * e;
  }
  mseValue = sum / sampleCount;
}

// ─── REFERENCE LOOKUP ────────────────────────────────────────────────────────
float refAtTime(float t) {
  float spd = profSpeed[0];
  for (int i = 0; i < PROFILE_SIZE; i++) {
    if (t >= profTime[i]) spd = profSpeed[i];
  }
  return spd;
}

// ─── HEADER ──────────────────────────────────────────────────────────────────
void drawHeader() {
  fill(ACCENT);
  textFont(monoFont); textSize(11);
  text("BUGGY SPEED PROFILE CHALLENGE", CX, 30);

  fill(DIM_COL);
  text("PID TRACKING DEMO  //  60s RUN  //  DISPLAY MODE", CX, 46);

  String timerStr = running || finished
    ? nf(min(elapsed, 60), 2, 1) + "s / 60.0s"
    : "00.0s / 60.0s";
  fill(running ? OK_COL : DIM_COL);
  textAlign(RIGHT);
  text(timerStr, CX + CW, 30);
  textAlign(LEFT);

  float prog = constrain(elapsed / 60.0, 0, 1);
  noStroke(); fill(BORDER);
  rect(CX, 50, CW, 4, 2);
  fill(running ? ACCENT : (finished ? OK_COL : DIM_COL));
  rect(CX, 50, CW * prog, 4, 2);
}

// ─── CHART ───────────────────────────────────────────────────────────────────
void drawChart() {
  noStroke(); fill(PANEL);
  rect(CX - 10, CY + 10, CW + 20, CH + 40, 4);

  stroke(GRID_COL); strokeWeight(1);
  float maxSpeed = 50;

  for (int i = 0; i <= 6; i++) {
    float x = CX + (i / 6.0) * CW;
    line(x, CY, x, CY + CH);
    fill(DIM_COL); noStroke();
    textFont(labelFont); textSize(10); textAlign(CENTER);
    text(i * 10 + "s", x, CY + CH + 14);
    stroke(GRID_COL);
  }
  for (int i = 0; i <= 5; i++) {
    float y = CY + CH - (i / 5.0) * CH;
    line(CX, y, CX + CW, y);
    fill(DIM_COL); noStroke();
    textAlign(RIGHT);
    text(i * 10 + " cm/s", CX - 4, y + 4);
    stroke(GRID_COL);
  }

  noStroke(); fill(DIM_COL);
  textFont(labelFont); textSize(10); textAlign(CENTER);
  text("TIME (seconds)", CX + CW / 2, CY + CH + 30);
  pushMatrix();
  translate(CX - 35, CY + CH / 2);
  rotate(-HALF_PI);
  text("SPEED (cm/s)", 0, 0);
  popMatrix();

  // Reference step trace
  stroke(ACCENT); strokeWeight(2.5); noFill();
  beginShape();
  for (int i = 0; i < PROFILE_SIZE; i++) {
    float x0 = CX + (profTime[i] / 60.0) * CW;
    float y0  = CY + CH - (profSpeed[i] / maxSpeed) * CH;
    float x1  = (i + 1 < PROFILE_SIZE) ? CX + (profTime[i+1] / 60.0) * CW : CX + CW;
    vertex(x0, y0); vertex(x1, y0);
  }
  endShape();

  // Actual speed trace
  if (sampleCount > 1) {
    stroke(ACTUAL_COL); strokeWeight(1.8); noFill();
    beginShape();
    for (int i = 0; i < sampleCount; i++) {
      float x = CX + (tSamples[i] / 60.0) * CW;
      float y = CY + CH - (actSamples[i] / maxSpeed) * CH;
      vertex(x, y);
    }
    endShape();
  }

  // Live cursor + dots
  if (running && !finished) {
    float cx = CX + (elapsed / 60.0) * CW;
    stroke(255, 255, 255, 60); strokeWeight(1);
    line(cx, CY, cx, CY + CH);
    float refY = CY + CH - (currentRef    / maxSpeed) * CH;
    float actY = CY + CH - (currentActual / maxSpeed) * CH;
    noStroke();
    fill(ACCENT);     ellipse(cx, refY, 8, 8);
    fill(ACTUAL_COL); ellipse(cx, actY, 8, 8);
  }

  noFill(); stroke(BORDER); strokeWeight(1);
  rect(CX, CY, CW, CH);

  // Legend
  int lx = CX + CW - 210, ly = CY + 12;
  noStroke(); fill(PANEL);
  rect(lx - 8, ly - 10, 200, 42, 3);
  stroke(BORDER); noFill();
  rect(lx - 8, ly - 10, 200, 42, 3);
  noStroke();
  fill(ACCENT);    rect(lx, ly,      24, 3);
  fill(TEXT_COL);  textFont(labelFont); textSize(11); textAlign(LEFT);
  text("REFERENCE SPEED", lx + 30, ly + 4);
  fill(ACTUAL_COL); rect(lx, ly + 16, 24, 3);
  fill(TEXT_COL);   text("ACTUAL SPEED", lx + 30, ly + 20);

  // MSE overlay (post-run)
  if (finished && mseValue >= 0) {
    textFont(bigFont); textSize(18); textAlign(CENTER);
    String mseStr = "MSE: " + nf(mseValue, 1, 2) + " (cm/s)\u00b2";
    float tw = textWidth(mseStr) + 30;
    noStroke(); fill(PANEL);
    rect(CX + CW / 2 - tw / 2, CY + 14, tw, 34, 4);
    stroke(WARN_COL); noFill();
    rect(CX + CW / 2 - tw / 2, CY + 14, tw, 34, 4);
    noStroke(); fill(WARN_COL);
    text(mseStr, CX + CW / 2, CY + 37);
    textAlign(LEFT);
  }
}

// ─── SIDE PANEL ──────────────────────────────────────────────────────────────
void drawSidePanel() {
  noStroke(); fill(PANEL);
  rect(PX, 20, PW, PH - 20, 4);
  stroke(BORDER); noFill();
  rect(PX, 20, PW, PH - 20, 4);

  int y = 44, x = PX + 14, colW = PW - 28;

  // ── WiFi ──
  sectionHeader("WiFi", x, y); y += 22;

  fill(DIM_COL); textFont(labelFont); textSize(10);
  text(ARDUINO_IP + ":" + ARDUINO_PORT, x, y + 10); y += 18;

  drawButton(wifiConnected ? "⏏  DISCONNECT" : "⚡  CONNECT",
             x, y, colW, 28,
             wifiConnected ? WARN_COL : OK_COL, true); y += 38;

  noStroke();
  fill(wifiConnected ? OK_COL : WARN_COL);
  ellipse(x + 6, y + 5, 8, 8);
  fill(TEXT_COL); textFont(labelFont); textSize(10);
  text(wifiStatus, x + 16, y + 9); y += 22;

  stroke(BORDER); line(x, y, x + colW, y); y += 14;

  // ── Start display button ──
  boolean canStart = !running && !finished;
  drawButton("▶  START DISPLAY",
             x, y, colW, 36,
             canStart ? OK_COL : DIM_COL, canStart); y += 48;

  // Clear / ready for next run
  drawButton("⟳  CLEAR",
             x, y, colW, 28,
             WARN_COL, !running); y += 40;

  stroke(BORDER); line(x, y, x + colW, y); y += 14;

  // ── Live readout ──
  sectionHeader("LIVE READOUT", x, y); y += 24;
  liveValue("REF SPEED",  nf(currentRef,    2, 1) + " cm/s", ACCENT,      x, y); y += 22;
  liveValue("ACT SPEED",  nf(currentActual, 2, 1) + " cm/s", ACTUAL_COL,  x, y); y += 22;
  liveValue("ERROR",      nf(abs(currentRef - currentActual), 2, 1) + " cm/s", WARN_COL, x, y); y += 22;
  liveValue("SAMPLES",    str(sampleCount),                   TEXT_COL,    x, y); y += 22;

  // ── Final MSE ──
  if (finished && mseValue >= 0) {
    y += 6;
    stroke(WARN_COL); line(x, y, x + colW, y); y += 14;
    fill(WARN_COL); textFont(monoFont); textSize(11);
    text("FINAL MSE", x, y + 10); y += 20;
    textFont(bigFont); textSize(22);
    text(nf(mseValue, 1, 2), x, y + 22);
    fill(DIM_COL); textFont(labelFont); textSize(10);
    text("(cm/s)\u00b2", x + textWidth(nf(mseValue, 1, 2)) + 4, y + 22);
  }
}

// ─── STATUS BAR ──────────────────────────────────────────────────────────────
void drawStatusBar() {
  int sy = H - 22;
  noStroke(); fill(BORDER);
  rect(0, sy, W, 22);

  textFont(labelFont); textSize(10); textAlign(LEFT);
  String state = running ? "● RUNNING" : (finished ? "■ COMPLETE" : "◌ IDLE");
  fill(running ? OK_COL : (finished ? WARN_COL : DIM_COL));
  text(state, 14, sy + 14);

  fill(DIM_COL); textAlign(CENTER);
  text("display only — no commands sent to buggy", W / 2, sy + 14);

  textAlign(RIGHT);
  text("BUGGY CHALLENGE GUI v3.0 DISPLAY  //  Processing 4.x", W - 14, sy + 14);
  textAlign(LEFT);
}

// ─── HELPERS ─────────────────────────────────────────────────────────────────
void sectionHeader(String label, int x, int y) {
  fill(ACCENT); textFont(monoFont); textSize(10);
  text("── " + label + " ──", x, y + 10);
}

void drawButton(String label, int x, int y, int w, int h,
                color col, boolean enabled) {
  boolean hover = enabled && mouseX > x && mouseX < x + w &&
                             mouseY > y && mouseY < y + h;
  noStroke(); fill(hover ? col : BORDER);
  rect(x, y, w, h, 3);
  if (!hover) { stroke(col); strokeWeight(1); noFill(); rect(x, y, w, h, 3); }
  fill(hover ? BG : col);
  textFont(monoFont); textSize(11); textAlign(CENTER);
  text(label, x + w / 2, y + h / 2 + 5);
  textAlign(LEFT);
}

void liveValue(String label, String val, color col, int x, int y) {
  fill(DIM_COL); textFont(labelFont); textSize(10);
  text(label, x, y + 10);
  fill(col); textAlign(RIGHT);
  text(val, PX + PW - 18, y + 10);
  textAlign(LEFT);
}

// ─── HIT TESTS ───────────────────────────────────────────────────────────────
String hitButton(int mx, int my) {
  int x = PX + 14, colW = PW - 28;
  // WiFi button: y = 44 + 22 + 18 = 84
  int y = 84;
  if (mx > x && mx < x + colW && my > y && my < y + 28) return "WIFI";
  // START DISPLAY: after wifi status line + divider = 84 + 38 + 22 + 14 = 158
  y = 158;
  if (mx > x && mx < x + colW && my > y && my < y + 36) return "START";
  // CLEAR: 158 + 48 = 206
  y = 206;
  if (mx > x && mx < x + colW && my > y && my < y + 28) return "CLEAR";
  return "";
}

// ─── MOUSE ───────────────────────────────────────────────────────────────────
void mousePressed() {
  String btn = hitButton(mouseX, mouseY);
  if (btn.equals("WIFI"))  toggleWifi();
  if (btn.equals("START") && !running && !finished) startDisplay();
  if (btn.equals("CLEAR") && !running) clearDisplay();
}

void clearDisplay() {
  running       = false;
  finished      = false;
  elapsed       = 0;
  sampleCount   = 0;
  mseValue      = -1;
  currentRef    = 0;
  currentActual = 0;
}
