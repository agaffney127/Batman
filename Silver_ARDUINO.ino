#include "config.h"
#include "functions.h"

char ssid[] = "Gotham";
char pass[] = "Bruce_Wayne";
int status = WL_IDLE_STATUS;
WiFiServer server(5200);
WiFiClient client;

volatile unsigned long right_pulse = 0;
volatile unsigned long right_duration = 0;


void setup() {
  Serial.begin(115200);

  //Wifi Network configuration
  Serial.print("Network␣named:␣"); // Starting an access point
  Serial.println(ssid);
  status = WiFi.beginAP(ssid, pass);
  Serial.println("Network␣started");
  IPAddress ip = WiFi.localIP();
  Serial.print("IP␣Address:␣");
  Serial.println(ip);
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
  pinMode(CD_clock, OUTPUT);
  pinMode(CD_control, OUTPUT);
  pinMode(CD_data, INPUT);
  pinMode(reset_CD, OUTPUT);
  pinMode(hall_right, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(hall_right), rightISR, FALLING);
  digitalWrite(reset_CD, HIGH);
  delay(10);
  digitalWrite(reset_CD, LOW);

  analogWrite(leftPermission, 0);
  analogWrite(rightPermission, 0);

}

int right = 100;
int left = 125;
String last_printed_state = "";
char command;
String num;
float value;
int distance = 0;

void loop() {
  WiFiClient newClient = server.available(); 
  if (newClient) {
    client = newClient;  // only overwrite when there's actually a new connection
  }

  if (client && client.connected()) {
    if (client.available()) { //only try to read when there's data
      msg = client.readStringUntil('\n'); 
      msg.trim();
      if (msg!= "STOP"){
        command = msg.charAt(0);
        num = msg.substring(2);
        value = num.toFloat();
      }

  if (command == 'F'){
    for(int i=0, i < value/5, i++);
      forward(value);
      distance += 5;
      client.print("DIST:");
      client.prinln(distance)
    client.prinln("DONE");
  }

  if (command == 'L'){
    spinLeft(100);
    client.prinln("DONE");
  }

  if (command == 'R'){
    spinRight(100);
    client.prinln("DONE");
  }



}
