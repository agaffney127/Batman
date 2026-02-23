// Imports and Variable for Wifi Communication
#include "WiFiS3.h"
char ssid[] = "Gotham";
char pass[] = "Bruce_Wayne";
int status = WL_IDLE_STATUS;
WiFiServer server(5200);
WiFiClient client;

bool hadObject = false;
// Pin Assignments
const int LIR = 8;
const int RIR = 7;
const int Scream = 11;
const int Echo = 12;
const int leftPermission = 0;
const int rightPermission = A0;
const int leftForward = 1;
const int leftReverse=2;
const int rightForward = A1;
const int rightReverse = A2;

//Variable for the use of the ultra sonic sensor
const int Safe_Distance= 30;
long duration;
int distance;

//intial mode for buggy until told otherwise
char mode = 'S';
String msg = "";

void right(){
  analogWrite(leftPermission,100);
  analogWrite(rightPermission,0);
  digitalWrite(leftForward,HIGH);
  digitalWrite(leftReverse,LOW);
}

void left(){
  analogWrite(rightPermission,100);
  analogWrite(leftPermission,0);
  digitalWrite(rightForward,HIGH);
  digitalWrite(rightReverse,LOW);
}

// Two function for the basics of turning right or left for set time
void spinRight(int duration){
  analogWrite(leftPermission,120);
  analogWrite(rightPermission,0);
  digitalWrite(leftForward,HIGH);
  digitalWrite(leftReverse,LOW);
  delay(duration);
  digitalWrite(leftForward,LOW);
  analogWrite(leftPermission,0); 
}

void spinLeft(int duration){
  analogWrite(rightPermission,100);
  analogWrite(leftPermission,0);
  digitalWrite(rightForward,HIGH);
  digitalWrite(rightReverse,LOW);
  delay(duration);
  digitalWrite(rightForward,LOW);
  analogWrite(rightPermission,0);
}

//Small step procedure for adjustments prompted by IR sensors
void Step_Right(){
  spinRight(50);
  client.println("Adjusting Course Right");
}

void Step_Left(){
  spinLeft(50);
  client.println("Adjusting Course Left");
}

// Funtions which return true if the buggy detects it has crossed the line
bool Left_Error(){
  if(digitalRead(LIR)==LOW){
    return true;

  }
  return false;
}


bool Right_Error(){
  if(digitalRead(RIR)==LOW){
    return true;

  }
  return false;
  }

void go(){
  analogWrite(leftPermission,100);
  analogWrite(rightPermission,100);

  digitalWrite(leftForward,HIGH);
  digitalWrite(rightForward,HIGH);
  digitalWrite(leftReverse,LOW);
  digitalWrite(rightReverse,LOW);
}

void stop(){
  analogWrite(leftPermission,0);
  analogWrite(rightPermission,0);
  digitalWrite(leftForward,LOW);
  digitalWrite(rightForward,LOW);
  digitalWrite(leftReverse,LOW);
  digitalWrite(rightReverse,LOW);

}

void reverse(){
  analogWrite(leftPermission,100);
  analogWrite(rightPermission,100);

  digitalWrite(leftReverse,HIGH);
  digitalWrite(rightReverse,HIGH);
  digitalWrite(leftForward,LOW);
  digitalWrite(rightForward,LOW); 
}



//Basic function for buggy to drive forward for duration
void Mush(int duration){
  analogWrite(leftPermission,105);
  analogWrite(rightPermission,100);


  digitalWrite(leftForward,HIGH);
  digitalWrite(rightForward,HIGH);
  digitalWrite(leftReverse,LOW);
  digitalWrite(rightReverse,LOW);
  

  client.println("Going Forward");
  delay(duration);

  digitalWrite(leftForward,LOW);
  digitalWrite(rightForward,LOW);
  analogWrite(leftPermission,0);
  analogWrite(rightPermission,0);
}


//returns true if an object closer than the safe distance
bool Bogie(){
 
  digitalWrite(Scream,LOW);
  delayMicroseconds(2);

  digitalWrite(Scream,HIGH);
  delayMicroseconds(10);
  digitalWrite(Scream,LOW);

  duration = pulseIn(Echo,HIGH);
  distance = duration/58;

  if(distance < Safe_Distance) {
    client.println("Obstacle in Path");
    hadObject = true
    return true;
  }
  if (hadObject)client.println("Object Removed");
  hadObject = false;
  return false;



}





void setup() {
  Serial.begin(115200);

//Wifi Network configuration
  Serial.print ("Network␣named:␣"); // Starting an access point
  Serial.println (ssid);
  status = WiFi.beginAP (ssid, pass);
  Serial.println ("Network␣started");
  IPAddress ip = WiFi.localIP ();
  Serial.print ("IP␣Address:␣");
  Serial.println (ip);
  server.begin();

//pin intialization
  pinMode(Scream,OUTPUT);
  pinMode(Echo,INPUT);
  pinMode(leftPermission,OUTPUT);
  pinMode(rightPermission,OUTPUT);
  pinMode(leftForward,OUTPUT);
  pinMode(rightForward,OUTPUT);
  pinMode(leftReverse,OUTPUT);
  pinMode(rightReverse,OUTPUT);
  pinMode(LIR,INPUT);
  pinMode(RIR,INPUT);

  analogWrite(leftPermission,0);
  analogWrite(rightPermission,0);

}

void loop() {
//read in current command from client
  client = server.available ();
  if (client){
    msg = client.readString();
    if (msg != ("")){
      mode = msg[0];
    }
  }

  
  if(mode == 'F'){
    if (!Bogie()){
      if (Right_Error()){
        while(Right_Error()){
          Step_Left();
        }
      }
      if(Left_Error()){
        while(Left_Error()){
          Step_Right();
        }
      }
      Mush(150);
    }
  }
  else client.println("Stopped");
  
}
