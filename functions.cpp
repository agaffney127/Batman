#include "functions.h"

byte shiftIn_r(int myDataPin, int myClockPin) {

  int i;

  int temp = 0;

  int pinState;

  byte myDataIn = 0;

  pinMode(myClockPin, OUTPUT);

  pinMode(myDataPin, INPUT);

  for (i=7; i>=0; i--)

  {

    digitalWrite(myClockPin, 0);

    delayMicroseconds(0.2);

    temp = digitalRead(myDataPin);

    if (temp) {

      pinState = 1;

      //set the bit to 0 no matter what

      myDataIn = myDataIn | (1 << i);

    }

    else {

      //turn it off -- only necessary for debugging

     //print statement since myDataIn starts as 0

      pinState = 0;

    }

    //Debugging print statements

    //Serial.print(pinState);

    //Serial.print("     ");

    //Serial.println (dataIn, BIN);

    digitalWrite(myClockPin, 1);

  }

  //debugging print statements whitespace

  //Serial.println();

  //Serial.println(myDataIn, BIN);

  return myDataIn;
}

byte left_pulse_count() {
  digitalWrite(CD_control, 1);   // load parallel data from CD4040
  delayMicroseconds(5);
  digitalWrite(CD_control, 0);    // switch to serial shift mode
  return shiftIn(CD_data, CD_clock, MSBFIRST); //this is the new built-in shifIn function, causes the pulse to skip by an increment of 2 tho so you have to manually implement
  //return shiftIn_r(CD_data, CD_clock); //nevermind the custom one has a different cm_per_pulse ratio and the pulse compare logic goes out the window. Better the devil you know, unless a way to fix
}


void rightISR() {
  const unsigned int CAN = 5000;
  static unsigned long lastPulse = 0;
  unsigned long now = micros();
  if (now - lastPulse > CAN) {  // ignore pulses less than 5ms apart
    right_pulse++;
    right_duration = now - lastPulse;
    lastPulse = now;
  }
}


/* earlier adoptation of the rightISR. The most basic case.
void rightISR() {
  right_pulse++;
}
*/


void forward(float cm, unsigned int left_power, unsigned int right_power,WiFiClient client) {
  unsigned int increm = 5;

  unsigned int left_power_new = left_power;
  unsigned int right_power_new = right_power;

  unsigned int pulse_all = cm / hall_const;
  //unsigned int pulse_all_left = cm / hall_const_left;
  //add pulse rem method. I.e what if we need 8.8 pulses, it needs to register 0.8 * hall_const for the remaining distance somehow
  
  //the great reset
  digitalWrite(reset_CD, HIGH);
  delay(10);
  digitalWrite(reset_CD, LOW);
  unsigned int left_pulse = 0;
  unsigned int prev_left_pulse = 0;
  unsigned long prev_left_time = micros();
  unsigned long left_duration = 0;
  float baseline_velocity_l = 0;
  float current_velocity_l = 0;

  noInterrupts();
  right_pulse = 0;
  unsigned long current_right;
  unsigned long current_interval;
  float baseline_velocity_r = 0;
  float current_velocity_r = 0;
  interrupts();

  //starting the motors
  digitalWrite(leftForward,HIGH);
  digitalWrite(rightForward,HIGH);
  digitalWrite(leftReverse,LOW);
  digitalWrite(rightReverse,LOW);


  bool left_done = 0;
  bool right_done = 0;

  //float distance_left;
  //float distance_right;
  //unsigned int lastSeenLeft = 0;
  //unsigned long lastSeenRight = 0;

  while (left_done == 0 || right_done == 0) { //so while at least one is still running
    left_pulse = left_pulse_count();
    if (left_pulse != prev_left_pulse && left_pulse % 4 == 0) {
      unsigned long now = micros();
      left_duration = now - prev_left_time;
      prev_left_time = now;
      prev_left_pulse = left_pulse;
    }
    //if (left_pulse % 4 != 0) continue;
    //checkRightEncoder();
    //right_pulse already exists as volatile;

    noInterrupts();
    current_right = right_pulse;
    current_interval = right_duration;
    interrupts();


    //break individually logic. The "smooth" logic with the loop might be a little wrong
    if (left_pulse >= pulse_all && left_done == 0) {
      //for (int i = left_power; i >= 0; i--) { //loop for smooth transition to a full stop not an abrupt one
      
        //delay(1);
      //}
      analogWrite(leftPermission, 0);
      left_done = 1;

    }
    if (current_right >= pulse_all && right_done == 0) {
      //for (int i = right_power; i >= 0; i--) {
        
        //delay(1);
      //}
      analogWrite(rightPermission, 0);
      right_done = 1;
    }

    if (left_done == 0 && right_done == 0) { //so while both are still running
      /*
      if (current_right <= 3) {
        baseline_velocity_r = hall_const / (current_interval / 1000000.0);
        baseline_velocity_l = (hall_const * 2) / (left_duration / 1000000.0);
        analogWrite(leftPermission,left_power);
        analogWrite(rightPermission,right_power);
      }
      */
      if (current_interval == 0 || left_duration == 0) {
        analogWrite(leftPermission,left_power);
        analogWrite(rightPermission,right_power);
      }

      
      if (current_interval > 0 && left_duration > 0) {
        
        current_velocity_r = hall_const / (current_interval / 1000000.0);
        if (left_pulse % 4 == 0) {
          current_velocity_l = (hall_const * 4) / (left_duration / 1000000.0);
        }
        float baseline_velocity = (current_velocity_l + current_velocity_r) / 2.0;
        current_speed = baseline_velocity;
        baseline_velocity_r = baseline_velocity;
        baseline_velocity_l = baseline_velocity;
        err_r = baseline_velocity_r - current_velocity_r;

        
        err_l = baseline_velocity_l - current_velocity_l;

        pid_r.Compute();
        pid_l.Compute();
      
        left_power_new = left_power - (int)correction_l;
        right_power_new = right_power - (int)correction_r;

        left_power_new = constrain(left_power_new, 100, 255);
        right_power_new = constrain(right_power_new, 100, 255); //the constrains shouldn't be equal

        analogWrite(leftPermission,left_power_new);
        analogWrite(rightPermission,right_power_new);
      }

      /*
      //diff = 1;
      //distance_left = left_pulse * hall_const_left;
      //distance_right = current_right * hall_const_right;
      if ((left_pulse > current_right)) { //whenever left pulse changes, the first signal has information. A brand new pulse of 2 is truly a 2. And if it is greater than the right's 1 for example, needs correction
        left_power_new= left_power_new - increm;
        right_power_new = right_power_new + increm;
        //left_power_new= left_power_new - (increm * diff);
        //right_power_new = right_power_new + (increm * diff);
      }
      else if (current_right > left_pulse + 1) {
        left_power_new = left_power_new + increm;
        right_power_new = right_power_new - increm;
        // left_power_new = left_power_new + (increm * diff);
        // right_power_new = right_power_new - (increm * diff);
      }
      */
      //delay(5);
    }

    
    
    if (left_pulse % 4 == 0) {
    Serial.print(left_pulse);
    Serial.print(" ");
    Serial.print(left_power_new);
    Serial.print("   ");
    Serial.print(right_pulse);
    Serial.print(" ");
    Serial.print(right_power_new);
    Serial.print("      ");
    
    
    Serial.print("E_l:");
    Serial.print(err_l);
    Serial.print(" C_l:");
    Serial.print(correction_l);
    Serial.print("  E_r:");
    Serial.print(err_r);
    Serial.print(" C_r:");
    Serial.print(correction_r);
    Serial.print("     VL:");
    Serial.print(current_velocity_l);
    Serial.print(" VR:");
    Serial.println(current_velocity_r);
    }
    client.print("DIST:");
    client.print(left_pulse * hall_const);
    client.print(",SPEED:");
    client.println(current_speed);
  }

  
  //stopping the motors for sure this time
  digitalWrite(leftForward,LOW);
  digitalWrite(rightForward,LOW);
  analogWrite(leftPermission,0);
  analogWrite(rightPermission,0);
}

void spinRight(int duration){
  analogWrite(leftPermission,100); //give left motor power of 120/255
  analogWrite(rightPermission,100); //spinning right only so right motor gets 0 power
  digitalWrite(leftForward,HIGH); //enable forward motion
  digitalWrite(leftReverse,LOW); //disable backwards motion
  digitalWrite(rightReverse,HIGH);
  digitalWrite(rightForward,LOW);
  delay(duration);
  digitalWrite(leftForward,LOW); //disable forward motion after set time
  analogWrite(leftPermission,0); //stop left motor
  digitalWrite(rightReverse,LOW);
  analogWrite(rightPermission,0);
}

void spinLeft(int duration){
  analogWrite(rightPermission,100);
  analogWrite(leftPermission,100);
  digitalWrite(rightForward,HIGH);
  digitalWrite(rightReverse,LOW);
  digitalWrite(leftReverse,HIGH);
  digitalWrite(leftForward,LOW);
  delay(duration);
  digitalWrite(rightForward,LOW);
  analogWrite(rightPermission,0);
  digitalWrite(leftReverse,LOW);
  analogWrite(leftPermission,0);
}

void Step_Right(){
  spinRight(25);
  //client.println("Adjusting Course Right");
}

void Step_Left(){
  spinLeft(25);
  //client.println("Adjusting Course Left");
}

bool Left_Error(){
  if(digitalRead(LIR)== LOW){
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

void Mush(int duration, int left, int right){
  analogWrite(leftPermission,left);
  analogWrite(rightPermission,right);


  digitalWrite(leftForward,HIGH);
  digitalWrite(rightForward,HIGH);
  digitalWrite(leftReverse,LOW);
  digitalWrite(rightReverse,LOW);
  
  //client.println("Going Forward");
  delay(duration);

  digitalWrite(leftForward,LOW);
  digitalWrite(rightForward,LOW);
  analogWrite(leftPermission,0);
  analogWrite(rightPermission,0);
}

bool Bogie(int Safe_Distance){
  long duration; //if needed for outside the function, we just pass by reference
  int distance;

  digitalWrite(Scream,LOW);
  delayMicroseconds(2);

  digitalWrite(Scream,HIGH);
  delayMicroseconds(10);
  digitalWrite(Scream,LOW);

  duration = pulseIn(Echo, HIGH); //appearently can add a timeout
  distance = duration/58;

  if(distance < Safe_Distance) {
    //client.println("Obstacle in Path");
    hadObject = true;
    return true;
  }
  //if (hadObject) client.println("Object Removed");
  //hadObject = false;
  return false;
}