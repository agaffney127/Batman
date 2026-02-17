import processing.net.*;
import controlP5.*;
Client myClient;
String data, mode;






void setup(){
  mode = "Stop";
  myClient = new Client(this,"192.168.4.1",5200);
  println("I hear you Oracle");
    myClient.write("Gotham Needs You");
  
}

void draw(){
  data = myClient.readString();
  if(data != null){
    print("Status: ");
    println(data);
  }s

  
}

void keyPressed(){
  if (key == 'f'){
     myClient.write("Forward");
   
  }
  if (key == 's'){
    myClient.write("Stop");
   
  }
}
