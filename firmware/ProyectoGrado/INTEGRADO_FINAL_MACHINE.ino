
#include <Wire.h>
#include <Adafruit_PWMServoDriver.h>

Adafruit_PWMServoDriver servos(0x40);

// =====================================
// CANALES
// =====================================
const byte BLANCA  = 2;
const byte PALETA2 = 1;
const byte PALETA3 = 0;
const byte PALETA4 = 15;
const byte PALETA5 = 8;

// =====================================
// PALETA 1 - BLANCA
// =====================================
const int blancaReposo = 330;
const int blancaArriba = 550;

const int pasoBlanca = 10;
const int tiempoBlanca = 10;

// =====================================
// PALETA 2 - SERVO 360 GRADOS
// =====================================
const int paleta2Stop = 369;
const int velocidadPaleta2 = 140;

// Mayor tiempo de subida
const unsigned long tiempoSubida2 = 2800;

// Tiempo de regreso
const unsigned long tiempoBajada2 = 1700;

// =====================================
// PALETA 3 - MAYOR RECORRIDO
// =====================================
const int paleta3Reposo = 90;
const int paleta3Arriba = 600;

const int pasoPaleta3 = 5;
const int tiempoPaleta3 = 15;

const unsigned long tiempoLlegada3 = 3000;

// =====================================
// PALETA 4 - CANAL 15
// =====================================
const int paleta4Reposo = 140;
const int paleta4Arriba = 500;

const int pasoPaleta4 = 10;
const int tiempoPaleta4 = 5;

const unsigned long tiempoLlegada4 = 2000;

// =====================================
// PALETA 5 - CANAL 8
// =====================================
const int paleta5Reposo = 600;
const int paleta5Arriba = 150;

const int pasoPaleta5 = 5;
const int tiempoPaleta5 = 10;

// Esperar antes de iniciar la paleta 3
const unsigned long tiempoLlegada5 = 2000;

// =====================================
// TIEMPOS GENERALES
// =====================================
const unsigned long esperaInicial = 5000;
const unsigned long esperaFinal = 10000;
const unsigned long esperaDespuesPaleta2 = 5000;

// =====================================
// FUNCION GENERAL DE MOVIMIENTO
// =====================================
void moverServo(
  byte canal,
  int inicio,
  int destino,
  int pasoPWM,
  int tiempoPaso,
  unsigned long tiempoLlegada
) {

  int pwm = inicio;

  while (pwm != destino) {

    if (pwm < destino) {
      pwm = min(pwm + pasoPWM, destino);
    }
    else {
      pwm = max(pwm - pasoPWM, destino);
    }

    servos.setPWM(canal, 0, pwm);
    delay(tiempoPaso);
  }

  // Mantener PWM final
  servos.setPWM(canal, 0, destino);

  // Esperar a completar movimiento
  if (tiempoLlegada > 0) {
    delay(tiempoLlegada);
  }
}

// =====================================
// PALETA 1 - BLANCA
// =====================================
void moverBlanca(int inicio, int destino) {

  moverServo(
    BLANCA,
    inicio,
    destino,
    pasoBlanca,
    tiempoBlanca,
    0
  );
}

// =====================================
// PALETA 3
// =====================================
void moverPaleta3(int inicio, int destino) {

  moverServo(
    PALETA3,
    inicio,
    destino,
    pasoPaleta3,
    tiempoPaleta3,
    tiempoLlegada3
  );
}

// =====================================
// PALETA 4
// =====================================
void moverPaleta4(int inicio, int destino) {

  moverServo(
    PALETA4,
    inicio,
    destino,
    pasoPaleta4,
    tiempoPaleta4,
    tiempoLlegada4
  );
}

// =====================================
// PALETA 5
// =====================================
void moverPaleta5(int inicio, int destino) {

  moverServo(
    PALETA5,
    inicio,
    destino,
    pasoPaleta5,
    tiempoPaleta5,
    tiempoLlegada5
  );
}

// =====================================
// PALETA 2 - SUBIR
// =====================================
void subirPaleta2() {

  Serial.println("PALETA 2 SUBIENDO");

  servos.setPWM(
    PALETA2,
    0,
    paleta2Stop + velocidadPaleta2
  );

  delay(tiempoSubida2);

  servos.setPWM(PALETA2, 0, paleta2Stop);

  Serial.println("PALETA 2 ARRIBA");
}

// =====================================
// PALETA 2 - BAJAR
// =====================================
void bajarPaleta2() {

  Serial.println("PALETA 2 BAJANDO");

  servos.setPWM(
    PALETA2,
    0,
    paleta2Stop - velocidadPaleta2
  );

  delay(tiempoBajada2);

  servos.setPWM(PALETA2, 0, paleta2Stop);

  Serial.println("PALETA 2 DETENIDA");
}

// =====================================
// SECUENCIA COMPLETA
// =====================================
void ejecutarCiclo() {

  Serial.println();
  Serial.println("==========================");
  Serial.println("INICIANDO CICLO");
  Serial.println("==========================");

  // ==================================
  // 1. BLANCA
  // ==================================
  Serial.println("BLANCA SUBIENDO");

  moverBlanca(blancaReposo, blancaArriba);

  Serial.println("BLANCA ARRIBA - 5 SEGUNDOS");
  delay(esperaInicial);

  Serial.println("BLANCA BAJANDO");

  moverBlanca(blancaArriba, blancaReposo);

  Serial.println("BLANCA EN REPOSO");

  // ==================================
  // 2. PALETA 4
  // ==================================
  Serial.println("PALETA 4 SUBIENDO");

  moverPaleta4(paleta4Reposo, paleta4Arriba);

  Serial.println("PALETA 4 ARRIBA");

  Serial.println("PALETA 4 BAJANDO");

  moverPaleta4(paleta4Arriba, paleta4Reposo);

  Serial.println("PALETA 4 EN REPOSO");

  // ==================================
  // 3. PALETA 5
  // ==================================
  Serial.println("PALETA 5 SUBIENDO");

  moverPaleta5(paleta5Reposo, paleta5Arriba);

  Serial.println("PALETA 5 ARRIBA");

  Serial.println("PALETA 5 BAJANDO");

  moverPaleta5(paleta5Arriba, paleta5Reposo);

  Serial.println("PALETA 5 EN REPOSO");

  // ==================================
  // 4. PALETA 3
  // ==================================
  Serial.println("PALETA 3 SUBIENDO");

  moverPaleta3(paleta3Reposo, paleta3Arriba);

  Serial.println("PALETA 3 ARRIBA");

  Serial.println("PALETA 3 BAJANDO");

  moverPaleta3(paleta3Arriba, paleta3Reposo);

  Serial.println("PALETA 3 EN REPOSO");

  // ==================================
  // 5. PALETA 2 - SERVO 360
  // ==================================
  Serial.println("PALETA 2 INICIANDO");

  subirPaleta2();

  bajarPaleta2();

  Serial.println("ESPERANDO 5 SEGUNDOS");
  delay(esperaDespuesPaleta2);

  // ==================================
  // 6. BLANCA FINAL
  // ==================================
  Serial.println("BLANCA SUBIENDO FINAL");

  moverBlanca(blancaReposo, blancaArriba);

  Serial.println("BLANCA ARRIBA - 10 SEGUNDOS");
  delay(esperaFinal);

  Serial.println("BLANCA BAJANDO FINAL");

  moverBlanca(blancaArriba, blancaReposo);

  Serial.println();
  Serial.println("==========================");
  Serial.println("CICLO FINALIZADO");
  Serial.println("ESCRIBE I PARA REPETIR");
  Serial.println("==========================");
}

// =====================================
// SETUP
// =====================================
void setup() {

  Serial.begin(9600);
  Serial.setTimeout(50);

  Wire.begin();

  servos.begin();
  servos.setPWMFreq(60);

  delay(1000);

  // POSICIONES INICIALES
  servos.setPWM(BLANCA, 0, blancaReposo);
  servos.setPWM(PALETA2, 0, paleta2Stop);
  servos.setPWM(PALETA3, 0, paleta3Reposo);
  servos.setPWM(PALETA4, 0, paleta4Reposo);
  servos.setPWM(PALETA5, 0, paleta5Reposo);

  delay(3000);

  Serial.println("==========================");
  Serial.println("MAQUINA DOBLADORA");
  Serial.println("5 PALETAS CONFIGURADAS");
  Serial.println("==========================");

  Serial.println("ORDEN:");
  Serial.println("1 - BLANCA");
  Serial.println("2 - PALETA 4");
  Serial.println("3 - PALETA 5");
  Serial.println("4 - PALETA 3");
  Serial.println("5 - PALETA 2");
  Serial.println("6 - BLANCA FINAL");

  Serial.println("==========================");
  Serial.println("I = INICIAR CICLO");
  Serial.println("E = ESTADO");
  Serial.println("==========================");
}

// =====================================
// LOOP
// =====================================
void loop() {

  if (Serial.available() > 0) {

    String comando = Serial.readStringUntil('\n');

    comando.trim();
    comando.toUpperCase();

    if (comando == "I") {

      ejecutarCiclo();

    }
    else if (comando == "E") {

      Serial.println("MAQUINA LISTA");
    }
    else {

      Serial.println("COMANDO NO RECONOCIDO");
    }
  }
}
