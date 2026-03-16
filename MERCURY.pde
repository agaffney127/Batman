import processing.net.*;

Client myClient;

// Command queue
ArrayList<Command> queue = new ArrayList<Command>();

// Command creation
String selectedCommand = "F";
int value = 50;

// Layout (queue wider now)
int leftPanel = 450;

// Execution control
int currentCommand = 0;
boolean running = false;
boolean waitingForArduino = false;

// Distance from Arduino
float distanceTravelled = 0;

void setup(){

  size(1000,600);
  windowTitle("Buggy Controller");

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

void drawControls(){

  fill(60);
  rect(0,0,leftPanel,120);

  drawButton("Forward",30,25);
  drawButton("Left",140,25);
  drawButton("Right",250,25);

  drawButton("Save Cmd",360,25);
  drawButton("Start",360,65);

  drawButton("STOP",140,65,255,50,50); // Emergency stop

  fill(255);
  textSize(16);
  text("Value: "+value+" (UP/DOWN)",30,100);

}

void drawCurrentCommand(){

  fill(70);
  rect(0,120,leftPanel,80);

  fill(255);
  textSize(18);

  text("Current Command:",30,155);

  String label="";

  if(selectedCommand.equals("F")) label="Forward";
  if(selectedCommand.equals("L")) label="Left";
  if(selectedCommand.equals("R")) label="Right";

  text(label+" "+value,30,180);

}

void drawDistance(){

  fill(70);
  rect(0,200,leftPanel,80);

  fill(255);
  textSize(18);

  text("Distance Travelled:",30,235);
  text(distanceTravelled+" cm",30,260);

}

void drawQueue(){

  fill(50);
  rect(leftPanel,0,width-leftPanel,height);

  fill(255);
  textSize(22);
  textAlign(CENTER);
  text("Command Queue",leftPanel+(width-leftPanel)/2,40);

  textSize(18);
  textAlign(LEFT);

  for(int i=0;i<queue.size();i++){

    Command c = queue.get(i);

    String label="";

    if(c.type.equals("F")) label="Forward";
    if(c.type.equals("L")) label="Left";
    if(c.type.equals("R")) label="Right";

    int y = 90 + i*35;

    // Highlight currently executing command
    if(running && i == currentCommand){

      fill(0,180,255);
      rect(leftPanel+10,y-20,width-leftPanel-20,30);

      fill(0);

    } else {

      fill(255);

    }

    text((i+1)+". "+label+" "+c.value,leftPanel+20,y);

  }

}

void drawButton(String label,int x,int y){

  drawButton(label,x,y,100,140,255);

}

void drawButton(String label,int x,int y,int r,int g,int b){

  int w = 100;
  int h = 32;

  fill(r,g,b);
  rect(x,y,w,h,8);

  fill(255);
  textAlign(CENTER,CENTER);
  text(label,x+w/2,y+h/2);

  textAlign(LEFT);

}

void mousePressed(){

  if(overButton(30,25)){
    selectedCommand="F";
    value=50;
  }

  if(overButton(140,25)){
    selectedCommand="L";
    value=90; // auto default
  }

  if(overButton(250,25)){
    selectedCommand="R";
    value=90; // auto default
  }

  if(overButton(360,25)){
    queue.add(new Command(selectedCommand,value));
  }

  if(overButton(360,65)){
    startExecution();
  }

  if(overButton(140,65)){ // STOP
    emergencyStop();
  }

}

boolean overButton(int x,int y){

  int w = 100;
  int h = 32;

  return mouseX>x && mouseX<x+w && mouseY>y && mouseY<y+h;

}

void keyPressed(){

  if(keyCode==UP) value+=10;

  if(keyCode==DOWN) value=max(10,value-10);

}

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

void emergencyStop(){

  println("EMERGENCY STOP");

  myClient.write("STOP\n");

  running=false;
  waitingForArduino=false;

}

class Command{

  String type;
  int value;

  Command(String t,int v){

    type=t;
    value=v;

  }

}
