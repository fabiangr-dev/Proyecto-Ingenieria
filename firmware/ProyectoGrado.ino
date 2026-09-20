#include <WiFi.h>

const char* ssid = "FIBRAZO-63530";
const char* password = "Ygranados0084";

WiFiServer server(80);
bool hmiConnected = false;

String readRequestBody(WiFiClient& client, int contentLength) {
  String body;
  unsigned long lastByteTime = millis();

  while (body.length() < contentLength || contentLength == 0) {
    while (client.available() &&
           (contentLength == 0 || body.length() < contentLength)) {
      body += static_cast<char>(client.read());
      lastByteTime = millis();
    }

    if (contentLength == 0 && body.length() > 0 &&
        millis() - lastByteTime > 100) {
      break;
    }

    if (millis() - lastByteTime > 1000) {
      break;
    }

    delay(1);
  }

  return body;
}

String extractJsonValue(const String& body, const String& key) {
  String searchKey = "\"" + key + "\":\"";
  int start = body.indexOf(searchKey);

  if (start < 0) {
    return "";
  }

  start += searchKey.length();
  int end = body.indexOf('"', start);

  if (end < 0) {
    return "";
  }

  return body.substring(start, end);
}

void sendJsonResponse(
  WiFiClient& client,
  int statusCode,
  const String& statusText,
  const String& body
) {
  client.print("HTTP/1.1 ");
  client.print(statusCode);
  client.print(" ");
  client.println(statusText);
  client.println("Content-Type: application/json");
  client.println("Connection: close");
  client.print("Content-Length: ");
  client.println(body.length());
  client.println();
  client.print(body);
}

void printButton(const String& button) {
  Serial.print("Boton presionado en HMI: ");
  Serial.println(button.length() > 0 ? button : "DESCONOCIDO");
}

void handleRequest(
  WiFiClient& client,
  const String& requestLine,
  const String& body
) {
  Serial.println("REQUEST:");
  Serial.println(requestLine);
  Serial.println("BODY:");
  Serial.println(body);

  if (requestLine.indexOf("POST /api/connect") >= 0) {
    String button = extractJsonValue(body, "button");
    printButton(button);
    hmiConnected = true;
    Serial.println("Conexion HMI establecida.");

    sendJsonResponse(
      client,
      200,
      "OK",
      "{\"status\":\"ok\",\"connection\":\"connected\"}"
    );
    return;
  }

  if (requestLine.indexOf("POST /api/disconnect") >= 0) {
    String button = extractJsonValue(body, "button");
    printButton(button);
    hmiConnected = false;
    Serial.println("Conexion HMI cerrada.");

    sendJsonResponse(
      client,
      200,
      "OK",
      "{\"status\":\"ok\",\"connection\":\"disconnected\"}"
    );
    return;
  }

  if (requestLine.indexOf("GET /api/state") >= 0) {
    sendJsonResponse(
      client,
      200,
      "OK",
      hmiConnected
        ? "{\"status\":\"ok\",\"connection\":\"connected\"}"
        : "{\"status\":\"ok\",\"connection\":\"disconnected\"}"
    );
    return;
  }

  if (requestLine.indexOf("POST /api/command") >= 0) {
    if (!hmiConnected) {
      Serial.println("Comando rechazado: HMI no conectado.");
      sendJsonResponse(
        client,
        409,
        "Conflict",
        "{\"status\":\"error\",\"message\":\"hmi_not_connected\"}"
      );
      return;
    }

    String button = extractJsonValue(body, "button");
    String command = extractJsonValue(body, "command");

    if (button.length() == 0 || command.length() == 0) {
      Serial.println("Comando rechazado: JSON incompleto.");
      sendJsonResponse(
        client,
        400,
        "Bad Request",
        "{\"status\":\"error\",\"message\":\"button_or_command_missing\"}"
      );
      return;
    }

    Serial.println("================================");
    printButton(button);
    Serial.print("Comando recibido: ");
    Serial.println(command);
    Serial.println("================================");

    sendJsonResponse(
      client,
      200,
      "OK",
      "{\"status\":\"ok\",\"button\":\"" + button + "\"}"
    );
    return;
  }

  sendJsonResponse(
    client,
    404,
    "Not Found",
    "{\"status\":\"error\",\"message\":\"route_not_found\"}"
  );
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println();
  Serial.println("Iniciando ESP32...");
  Serial.println("Conectando a WiFi...");

  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println();
  Serial.println("WiFi conectada.");
  Serial.print("IP del ESP32: ");
  Serial.println(WiFi.localIP());

  server.begin();
  Serial.println("Servidor HTTP iniciado.");
}

void loop() {
  WiFiClient client = server.available();

  if (!client) {
    return;
  }

  Serial.println("Cliente conectado.");
  client.setTimeout(5000);

  String requestLine = client.readStringUntil('\r');
  client.readStringUntil('\n');

  int contentLength = 0;
  String headerLine;

  while (client.connected()) {
    headerLine = client.readStringUntil('\r');
    client.readStringUntil('\n');

    if (headerLine.length() == 0) {
      break;
    }

    String normalizedHeader = headerLine;
    normalizedHeader.toLowerCase();

    if (normalizedHeader.startsWith("content-length:")) {
      int colon = normalizedHeader.indexOf(':');
      contentLength = normalizedHeader.substring(colon + 1).toInt();
    }
  }

  String body = "";

  Serial.print("Content-Length detectado: ");
  Serial.println(contentLength);

  body = readRequestBody(client, contentLength);

  if (body.length() > 0) {
    Serial.print("Bytes recibidos en BODY: ");
    Serial.println(body.length());
  }

  handleRequest(client, requestLine, body);

  client.flush();
  delay(100);
  client.stop();
  Serial.println("Cliente desconectado.");
  Serial.println("--------------------------------");
}
