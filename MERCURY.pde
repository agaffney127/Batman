import processing.net.*;

Client myClient;

// Command queue
ArrayList<Command> queue = new ArrayList<Command>();

// Command creation
String selectedCommand = "F";
int value = 50;

// Layout
int panelWidth = 400;
int centerX;

// Button layout
int btnW = 120;
int btnH = 40;
int gap = 20;

// Execution control
int currentCommand = 0;
boolean running = false;
boolean waitingForArduino = false;

// Distance from Arduino
float distanceTravelled = 0;

void setup(){

  size(1000,600);
  windowTitle("Buggy Controller");

  centerX = panelWidth/2;

  myClient = new Client(this,"192.168.4.1",5200);
  println("Connected to buggy");

}

void draw(){

  background(30);

  drawControls();
  drawCurrentCommand();
  drawDistance();
  drawQueue();

  checkArduinoResponse();

}

// ---------------- UI ----------------

void drawControls(){

  fill(60);
  rect(0,0,panelWidth,180);

  int startX = centerX - (btnW*3 + gap*2)/2;

  // Row 1 (movement)
  drawButton("Forward", startX, 25);
  drawButton("Left", startX + btnW + gap, 25);
  drawButton("Right", startX + (btnW + gap)*2, 25);

  // Row 2 (actions)
  int row2X = centerX - (btnW*2 + gap)/2;

  drawButton("Save Cmd", row2X, 85);
  drawButton("Start", row2X + btnW + gap, 85);

  // Row 3 (controls)
  int row3X = centerX - (btnW*2 + gap)/2;

  drawButton("STOP", row3X, 135, 255,50,50);
  drawButton("CLEAR", row3X + btnW + gap, 135, 200,100,255);

  fill(255);
  textAlign(CENTER);
  textSize(16);
  text("Value: "+value+" (UP/DOWN)", centerX, 170);

  textAlign(LEFT);
}

void drawCurrentCommand(){

  fill(70);
  rect(0,180,panelWidth,90);

  fill(255);
  textSize(18);

  textAlign(CENTER);
  text("Current Command:", centerX, 210);

  String label="";

  if(selectedCommand.equals("F")) label="Forward";
  if(selectedCommand.equals("L")) label="Left";
  if(selectedCommand.equals("R")) label="Right";

  text(label+" "+value, centerX, 240);

  textAlign(LEFT);
}

void drawDistance(){

  fill(70);
  rect(0,270,panelWidth,90);

  fill(255);
  textSize(18);

  textAlign(CENTER);
  text("Distance Travelled:", centerX, 300);
  text(distanceTravelled+" cm", centerX, 330);

  textAlign(LEFT);
}

void drawQueue(){

  fill(50);
  rect(panelWidth,0,width-panelWidth,height);

  fill(255);
  textSize(24);
  textAlign(CENTER);
  text("Command Queue", panelWidth + (width-panelWidth)/2,40);

  textSize(18);
  textAlign(LEFT);

  for(int i=0;i<queue.size();i++){

    Command c = queue.get(i);

    String label="";
    if(c.type.equals("F")) label="Forward";
    if(c.type.equals("L")) label="Left";
    if(c.type.equals("R")) label="Right";

    int y = 90 + i*40;

    if(running && i == currentCommand){

      fill(0,180,255);
      rect(panelWidth+20,y-25,width-panelWidth-40,35);

      fill(0);

    } else {
      fill(255);
    }

    text((i+1)+". "+label+" "+c.value, panelWidth+30, y);
  }
}

// ---------------- BUTTONS ----------------

void drawButton(String label,int x,int y){
  drawButton(label,x,y,100,140,255);
}

void drawButton(String label,int x,int y,int r,int g,int b){

  fill(r,g,b);
  rect(x,y,btnW,btnH,10);

  fill(255);
  textAlign(CENTER,CENTER);
  textSize(14);
  text(label,x+btnW/2,y+btnH/2);

  textAlign(LEFT);
}

// ---------------- INPUT ----------------

void mousePressed(){

  int startX = centerX - (btnW*3 + gap*2)/2;

  if(overButton(startX,25)){
    selectedCommand="F";
    value=50;
  }

  if(overButton(startX + btnW + gap,25)){
    selectedCommand="L";
    value=90;
  }

  if(overButton(startX + (btnW + gap)*2,25)){
    selectedCommand="R";
    value=90;
  }

  int row2X = centerX - (btnW*2 + gap)/2;

  if(overButton(row2X,85)){
    queue.add(new Command(selectedCommand,value));
  }

  if(overButton(row2X + btnW + gap,85)){
    startExecution();
  }

  int row3X = centerX - (btnW*2 + gap)/2;

  if(overButton(row3X,135)){
    emergencyStop();
  }

  if(overButton(row3X + btnW + gap,135)){
    clearQueue();
  }
}

boolean overButton(int x,int y){
  return mouseX>x && mouseX<x+btnW && mouseY>y && mouseY<y+btnH;
}

void keyPressed(){
  if(keyCode==UP) value+=10;
  if(keyCode==DOWN) value=max(10,value-10);
}

// ---------------- EXECUTION ----------------

void startExecution(){

  if(queue.size()==0) return;

  println("Starting command execution");

  running = true;
  currentCommand = 0;

  sendNextCommand();
}

void sendNextCommand(){

  if(currentCommand >= queue.size()){
    println("All commands complete");
    running=false;
    return;
  }

  Command c = queue.get(currentCommand);

  String message = c.type + ":" + c.value;

  println("Sending -> "+message);

  myClient.write(message+"\n");

  waitingForArduino = true;
}

void checkArduinoResponse(){

  String data = myClient.readStringUntil('\n');

  if(data != null){

    data = trim(data);

    println("Arduino: " + data);

    if(data.startsWith("DIST:")){
      String valueStr = data.substring(5);
      distanceTravelled = float(valueStr);
    }

    if(data.equals("DONE") && waitingForArduino){
      waitingForArduino = false;
      currentCommand++;
      sendNextCommand();
    }
  }
}

// ---------------- EXTRA ----------------

void emergencyStop(){

  println("EMERGENCY STOP");

  myClient.write("STOP\n");

  running=false;
  waitingForArduino=false;
}

void clearQueue(){

  println("Queue cleared");

  queue.clear();
  running = false;
  waitingForArduino = false;
  currentCommand = 0;
}

// ---------------- CLASS ----------------

class Command{

  String type;
  int value;

  Command(String t,int v){
    type=t;
    value=v;
  }
}
