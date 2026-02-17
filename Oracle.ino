
#include "WiFiS3.h"
char ssid[] = "Gotham";
char pass[] = "Bruce_Wayne";
int status = WL_IDLE_STATUS;
WiFiServer server(5200);
void setup() {
  Serial.begin (115200);
  Serial.print ("Network␣named:␣"); // Starting an access point
  Serial.println (ssid);
  status = WiFi.beginAP (ssid, pass);
  Serial.println ("Network␣started");
  IPAddress ip = WiFi.localIP ();
  Serial.print ("IP␣Address:␣");
  Serial.println (ip);
  server.begin(); // Starting a server
}
void loop() {
  String msg;
  WiFiClient client = server.available ();
  if(client){
    client.println("I'm Batman ");
    msg = client.readString();
    Serial.println(msg);

  }
  delay(10);
}
