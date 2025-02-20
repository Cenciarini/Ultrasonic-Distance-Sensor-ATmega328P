# 📡 Sensor de Distancia con ATmega328P (Assembly)

## 📌 Descripción
Este proyecto implementa un **sensor de distancia** utilizando un microcontrolador **ATmega328P**. Se usa un sensor ultrasónico para medir la distancia y mostrar los resultados a través de comunicación serie y LEDs.

## 🔧 Características
- **Medición de distancia** con sensor ultrasónico (HC-SR04).
- **Gestión de comunicación serie** mediante buffers circulares.
- **Control de estado** mediante registros en `GPIOR0`.
- **Indicación visual** con LEDs en el microcontrolador.

## 🔌 Hardware Utilizado
- **Microcontrolador:** ATmega328P
- **Sensor Ultrasónico:** HC-SR04
- **LEDs indicadores**
- **Interfaz serie UART**

## 📜 Registros y Flags
El sistema usa `GPIOR0` para manejar estados internos:

| Registro | Descripción |
|----------|------------|
| `LASTSTATEBTN` | Último estado del pulsador |
| `DATAREADY` | Indica si hay un nuevo comando |
| `CALCULAR` | Señal para calcular la distancia |
| `MIDIENDO` | Indica si se está midiendo la distancia |
| `ISNEWBTN` | Detecta cambios en el pulsador |
| `IS10MS` | Indica si han pasado 10ms |

## 📡 Pines de Control
El sistema usa los siguientes pines:

| Nombre | Pin | Función |
|--------|-----|---------|
| `LEDBUILTIN` | D13 (PB5) | LED de estado |
| `ECHO` | D8 (PB0) | Señal de eco del sensor ultrasónico |
| `TRIG` | D11 (PB3) | Señal de disparo del sensor ultrasónico |

## 🔄 Buffer Circular para Comunicación Serie
El código maneja datos a través de UART utilizando un **buffer circular**:

| Variable | Descripción |
|----------|------------|
| `buffRX` | Buffer de recepción (64 bytes) |
| `buffTX` | Buffer de transmisión (64 bytes) |
| `indexRXw` | Índice de escritura en RX |
| `indexRXr` | Índice de lectura en RX |
| `nBytesRX` | Número de bytes en el buffer RX |

## 🛠️ Funcionamiento
1. **El microcontrolador envía un pulso de activación** (`TRIG`).
2. **El sensor ultrasónico devuelve un pulso** (`ECHO`) cuya duración indica la distancia.
3. **El microcontrolador calcula la distancia** y la almacena en variables.
4. **El resultado se envía a través de UART** y se indica con LEDs.

## 🚀 Simulación y Pruebas
Para verificar el correcto funcionamiento del sistema:
1. **Simulación en software**: Usar Proteus o una herramienta compatible con AVR.
2. **Prueba con hardware**: Conectar el sensor y visualizar resultados en serie.
3. **Verificación de comunicación UART** con un terminal serie.

## 📜 Licencia
Este proyecto está disponible bajo la licencia **MIT**.

---
✉️ **Autor**: CENCIARINI Angel Gabriel & RE Sebastian
📍 **Proyecto de Medición de Distancia con ATmega328P**
