;
; SensorDistancia.asm
;
; Created: 6/9/2023 19:12:30
; Author : Cenciarini and Re
;

#include <m328pdef.inc>

;**** GPIOR0 como regsitros de banderas ****
.equ LASTSTATEBTN = 0	;GPIOR0<0>: ultimo estado pulsador
.equ DATAREADY	  = 1	;GPIOR0<1>: Hay un nuevo comando
.equ CALCULAR	  = 2	;GPIOR0<2>: Calcular distancia
.equ MIDIENDO	  = 3 	;GPIOR0<3>:  
;GPIOR0<4>:  
;GPIOR0<5>:  
.equ ISNEWBTN	  = 6	;GPIOR0<6>: cambio el estado del pulsador
.equ IS10MS	  = 7	;GPIOR0<7>: pasaron 10ms
;****

;****BUTTONS and LEDS****
.equ LEDBUILTIN	  = 5	;PINB (D13)
//.equ LED0		  = 1	;PINB (D9)
.equ ECHO		  = 0   ;PINB (D8)
.equ TRIG		  = 3   ;PINB (D11)
;***

;****RING BUFFER DEFINTIONS****
.equ SIZERXBUF = 64	;Must to be 2^n
.equ SIZETXBUF = 64	;Must to be 2^n
;****

.dseg
counter:	.BYTE	2
heartbeat:	.BYTE	2
maskLeds:	.BYTE	2
time10ms:	.BYTE	1
time100ms:	.BYTE	1
dbButton:	.BYTE	1
;DATA for RING BUFFER
buffRX:		.BYTE	SIZERXBUF
indexRXw:	.BYTE	1
indexRXr:	.BYTE	1
headerRX:	.BYTE	1
nBytesRX:	.BYTE	1
tmoRX:		.BYTE	1
iDataRX:	.BYTE	1
cksRX:		.BYTE	1
buffTX:		.BYTE	SIZETXBUF
indexTXw:	.BYTE	1
indexTXr:	.BYTE	1
nBytesTX:	.BYTE	1

COUNTON:	.BYTE	2
COUNTOFF:	.BYTE	2

distanceMs:	.BYTE	2
distanceM:	.BYTE	1
;

.cseg
.org	0x00
	jmp	start
.org	0x0014
	jmp ISR_TIMER1_CAPT
.org 0x0016
	jmp ISR_TIM1_COMPA
.org	0x1C
	jmp	ISR_TIMER0_COMPA
.org	0x24	
	jmp	ISR_USART_RX
.org	0x34

version:	.db	"20230824_01b01", '\n', 0

//INTERRUPCIONES
ISR_TIMER1_CAPT:
	lds	r2, SREG		;Salvo el registro de estado
	push r2
	push r16
	push r17

	lds r16, TCCR1B
	sbrc r16, ICES1 
	rjmp ISR_FA  ;entra si es 1

	sbr r16, (1<<ICES1)   ;Flanco Ascendente
	sts TCCR1B, r16
	lds r16, TIMSK1
	cbr r16, (1<<ICIE1)
	sts TIMSK1, r16

	lds r16, ICR1L
	lds r17, ICR1H
	sts COUNTOFF+1, r17
	sts COUNTOFF, r16
	

	sbi GPIOR0, CALCULAR
	rjmp outISR

ISR_FA:
	cbr r16, (1<<ICES1)   ;Flanco Descendente
	sts TCCR1B, r16
	lds r16, ICR1L
	lds r17, ICR1H
	sts COUNTON, r16
	sts COUNTON+1, r17

outISR: 
	pop r17
	pop r16
	pop r2
	out SREG,r2
	reti

ISR_TIM1_COMPA: 
	push r16
	//ldi r16, PORTB
	cbi PORTB, TRIG ;Trigger Low
	lds r16, TIFR1
	sts TIFR1, r16
	lds r16, TCCR1B
	sbr r16, (1<<ICES1)   ;Flanco Ascendente
	sts TCCR1B, r16
	lds r16, TIMSK1
	sbr r16, (1<<ICIE1)
	cbr r16, (1<<OCIE1A)
	sts TIMSK1, r16
	pop r16

	reti

ISR_TIMER0_COMPA:
	;Salvo el registro de estado
	push	r2
	in	r2, SREG
	push	r16
	lds	r16, time10ms
	dec	r16
	sts	time10ms, r16
	brne	outCOMPA
	ldi	r16, 5
	sts	time10ms, r16
	sbi	GPIOR0, IS10MS
outCOMPA:
	pop	r16			;vuelvo r16 a su estado antes de antender la interrupcion
	out	SREG, r2		;dejo STATUS como antes de la interrupcion
	pop	r2			
	reti

ISR_USART_RX:
	push	r2
	in	r2, SREG
	push	r16
	push	r17
	push	r26
	push	r27
	ldi	r27, high(buffRX)
	ldi	r26, low(buffRX)
	lds	r16, indexRXw
	clr	r17
	add	r26, r16
	adc	r27, r17
	lds	r17, UDR0
	st	X, r17
	inc	r16
	andi	r16, SIZERXBUF-1	;avoid buffRX overflow (SIZEBUFRX must to be 2^n)
	sts	indexRXw, r16
	pop	r27
	pop	r26
	pop	r17
	pop	r16
	out	SREG, r2
	pop	r2
	reti

//FUNCIONES DE INICIALIZACION
;PB5<5, 1>: OUTPUT PB<0>: INPUT(Pullup)
;PIN ON CHANGE en PB0
initPorts:
	ldi	r16, (1 << LEDBUILTIN) | (1<<TRIG) ;0b00100010
	out	DDRB, r16
	in	r16, PCIFR
	eor	r16, r16		;Reset de todas la banderas
	out	PCIFR, r16
	ldi	r16, (1 << PCINT0)
	sts	PCMSK0, r16
	lds	r16, PCICR
	sbr	r16, (1 << PCIE0)
	sts	PCICR, r16
	ret

;OCF0A cada 2ms CTC
initTmr0:
	ldi	r16, 0x02
	out	TCCR0A, r16
	sbi	TIFR0, (1 << OCF0A)
	ldi	r16, 124
	out	OCR0A, r16
	ldi	r16, (1 << OCIE0A)
	sts	TIMSK0, r16 
	ldi	r16, 0b00000100
	out	TCCR0B, r16
	ret

init_timer1:
	ldi r16,0x00
	sts TCCR1A,r16
	sbi TIFR1, (1 << OCF1A)
	ldi r16,0xCA
	sts TCCR1B,r16
/*	ldi r18,high(TOP)
	sts OCR1AH,r18
	ldi r18,low(TOP)
	sts OCR1AL,r18	
	ldi r16, (1 << OCIE1A) //Habilita la interrupcion
	ldi r16,0x22
	sts TIMSK1,r16*/
	ret


initUsart0: ; 115200, 8,N,1
	ldi	r16,0xfe
	sts	UCSR0A,r16
	ldi	r16,16
	sts	UBRR0L,r16
	ldi	r16,0
	sts	UBRR0H,r16
	ldi	r16,0x06
	sts	UCSR0C,r16
	ldi	r16,0x98
	sts	UCSR0B,r16
	ret

doLeds:
	lds	r16, maskLeds
	lds	r17, maskLeds+1
	lds	r18, heartbeat
	lds	r19, heartbeat+1
	and	r18, r16
	brne	onHeartbeat
	and	r19, r17
	brne	onHeartbeat
	cbi	PORTB, LEDBUILTIN
	ret

onHeartbeat:
	sbi	PORTB, LEDBUILTIN

rorMaskHeartbeat:
	clc
	ror	r16
	ror	r17
	sbrs	r17, 5
	rjmp	outHeartbeat
	clr	r17
	ldi	r16, 0x80

outHeartbeat:		
	sts	maskLeds, r16
	sts	maskLeds+1, r17
	ret

do100ms:
	lds	r16, time100ms
	dec	r16
	sts	time100ms, r16
	breq	PC+2
	ldi	r16, 10
	sts	time100ms, r16

	ldi r16, TIFR1
	cbr r16 , (1<<OCF1A)
	sts TIFR1,r16
	lds r16,TCNT1L
	lds r17,TCNT1H
	ldi r18,20
	add r16,r18
	brcc PC+2
	inc r17
	sts OCR1AH,r16
	sts OCR1AL,r17
	ldi r16, (1 << OCIE1A)
	sts TIMSK1,r16
	sbi PORTB, TRIG ;Trigger High
	call	doLeds

testTmoRX:
	lds	r16, headerRX
	tst	r16
	brne	PC+2
	ret
	lds	r16, tmoRX
	dec	r16
	sts	tmoRX, r16
	breq	PC+2
	ret
	clr	r16
	sts	headerRX, r16
	ret

DecodeHeader:
	lds	r17, indexRXw
	lds	r16, indexRXr
readByteRX:
	ldi	r27, high(buffRX)
	ldi	r26, low(buffRX)
	add	r26, r16
	brcc	PC+2
	subi	r27, -1
	cpse	r16, r17
	rjmp	nextByteHeader
	nop
	ret
nextByteHeader:
	ld	r19, X
	lds	r18, headerRX
	cpi	r18, 6		;STATE waiting n bytes of data
	breq	waitingData
	cpi	r18, 5		;STATE token ':'
	breq	waitToken
	cpi	r18, 4		;STATE nBytes
	breq	waitNBytes
	cpi	r18, 3		;STATE 'R'
	breq	waitR
	cpi	r18, 2		;STATE 'E'
	breq	waitE
	cpi	r18, 1		;STATE 'N'
	breq	waitN
	cpi	r18, 0		;STATE 'U'
	breq	waitU
resetHeader:
	ldi	r18, 255
nextHeader:
	inc	r18
	sts	headerRX, r18
nextByteRX:
	andi	r16, SIZERXBUF-1
	subi	r16, -1
	andi	r16, SIZERXBUF-1
	sts	indexRXr, r16
	rjmp	readByteRX
waitU:
	cpi	r19, 'U'
	breq	PC+2
	rjmp	nextByteRX
	ldi	r19, 3
	sts	tmoRX, r19
	rjmp	nextHeader
waitN:	
	cpi	r19, 'N'
	breq	nextHeader
	subi	r16, 1
	rjmp	resetHeader
waitE:	
	cpi	r19, 'E'
	breq	nextHeader
	subi	r16, 1
	rjmp	resetHeader
waitR:	
	cpi	r19, 'R'
	breq	nextHeader
	subi	r16, 1
	rjmp	resetHeader
waitNBytes:
	sts	nBytesRx, r19
	sts	cksRX, r19
	rjmp	nextHeader
waitToken:	
	cpi	r19, ':'
	breq	cksRXInit
	subi	r16, 1
	rjmp	resetHeader
cksRXInit:
	ldi	r19, 'U' ^ 'N' ^ 'E' ^ 'R' ^ ':'
	lds	r2, cksRX
	eor	r2, r19
	sts	cksRX, r2
	inc	r16
	andi	r16, SIZERXBUF-1
	sts	iDataRX, r16
	dec	r16
	rjmp	nextHeader
waitingData:
	lds	r20, nBytesRX
	dec	r20
	sts	nBytesRX, r20
	cpi	r20, 0
	breq	checkCksRX
	lds	r2, cksRX
	eor	r2, r19
	sts	cksRX, r2
	rjmp	nextByteRX
checkCksRX:
	lds	r2, cksRX
	cbi	GPIOR0, DATAREADY
	cp	r19, r2
	brne	PC+2
	sbi	GPIOR0, DATAREADY
	rjmp	resetHeader
			
		
;r2 cksTX
;r16 iDataRX
;r17 indexTXw
DecodeCMD:
	ldi	r16, 'U' ^ 'N' ^ 'E' ^ 'R' ^ ':'
	mov	r2, r16
	lds	r17, indexTXw
	subi	r17, -6			
	andi	r17, SIZETXBUF-1
	lds	r16, iDataRX
	call	GetByteFromRx
	cpi	r19, 0xF0	;0xF0	ALIVE
	brne	PC+2
	rjmp	doALIVE
	cpi	r19, 0xF1	;0xF1	FIRMWARE
	brne	PC+2
	rjmp	doFIRMWARE
	cpi	r19, 0xD0	;0xD0	ORDENA MEDIR
	brne	PC+2
	rjmp	doMEDIR
	cpi	r19, 0xD1	;0xD1	PIDE MEDIDA
	brne	PC+2
	rjmp	doMANDAR
	ret
doMEDIR:
	call	PutByteOnTx
	call	GetByteFromRx
	cpi	r19, 0x01
	brne medirOFF
	sbi GPIOR0, MIDIENDO
	rjmp medirOUT
medirOFF:
	cbi GPIOR0, MIDIENDO
medirOUT:
	ldi	r19, 3		;3 bytes of data 
	eor	r2, r19
	sts	nBytesTX, r19
	rjmp	putHeader
doMANDAR:
	call	PutByteOnTx
	lds r19, distanceM
	//lds r19, distanceMs+1
	call	PutByteOnTx
	//lds r19, distanceMs
	call	PutByteOnTx
	ldi	r19, 4		;3 bytes of data 
	eor	r2, r19
	sts	nBytesTX, r19
	rjmp	putHeader
doALIVE:
	call	PutByteOnTx
	ldi	r19, 0x0D
	call	PutByteOnTx
	ldi	r19, 3		;3 bytes of data 
	eor	r2, r19
	sts	nBytesTX, r19
	rjmp	putHeader
doFIRMWARE:
	call	PutByteOnTx
	ldi	r30, low(version << 1)
	ldi	r31, high(version << 1)
	ldi	r16, 14		;sizeof(version)
nextVersionChar:	
	lpm	r19, Z+
	call	PutByteOnTx
	dec	r16
	brne	nextVersionChar
	ldi	r19, 14 + 1	;15 bytes of data
	eor	r2, r19
	sts	nBytesTX, r19
putHeader:
	mov	r19, r2
	call	PutByteOntx		;Add checksum to buffTX
	sts	indexTXw, r17
	lds	r16, nBytesTx
	subi	r16, -6
	sub	r17, r16
	andi	r17, SIZETXBUF-1
	ldi	r19, 'U'
	call	PutByteOnTx
	ldi	r19, 'N'
	call	PutByteOnTx
	ldi	r19, 'E'
	call	PutByteOnTx
	ldi	r19, 'R'
	call	PutByteOnTx
	lds	r19, nBytesTX
	call	PutByteOnTx
	ldi	r19, ':'
	call	PutByteOnTx
	ret



;USE	R27:R26 buffRX
;INPUT	R16 iDataRX
;OUTPUT	R19 data byte
;Read a byte from a buffRX, increment iDataRX 
GetByteFromRx:
	ldi	r27, high(buffRX)
	ldi	r26, low(buffRX)
	add	r26, r16
	brcc	PC+2
	subi	r27, -1
	ld		r19, X
	inc	r16
	andi	r16, SIZERXBUF-1
	ret

;USE	R29:R28 buffTX
;INPUT	R17 indexTXw
;INPUT	R2 cksTX
;INPUT	R19 data byte
;Add a byte in a buffTX, increment indexTXw, and add checksum 
PutByteOnTx:
	eor	r2, r19
	ldi	r29, high(buffTX)
	ldi	r28, low(buffTX) 
	add	r28, r17
	brcc	PC+2
	subi	r29, -1
	st	Y, r19
	inc	r17
	andi	r17, SIZETXBUF-1
	ret

;INPUT R30, R31 the address of Constant text in flash
;The string must terminate with a null character
;The null character is also sent
PutConstTextOnTx:
	push	r16
	push	r17
	push	r26
	push	r27
	lds	r16, indexTXw
nextByteText:
	ldi	r27, high(buffTX)
	ldi	r26, low(buffTX)
	add	r26, r16
	brcc	PC+2
	subi	r27, -1
	inc	r16
	andi	r16, SIZETXBUF-1
	lpm	r17, Z+
	cpi	r17, '\0'
	st	X, r17
	brne	nextByteText
	sts	indexTXw, r16
	pop	r27
	pop	r26
	pop	r17
	pop	r16
	ret

TxData:
	lds	r16, UCSR0A
	sbrs	r16, UDRE0
	ret
	cbr	r16, (1 << TXC0)
	ldi	r27, high(buffTX)
	ldi	r26, low(buffTX)
	lds	r16, indexTXr
	add	r26, r16
	brcc	PC+2
	subi	r27, -1
	inc	r16
	andi	r16, SIZETXBUF-1
	sts	indexTXr, r16
	ld	r16, X
	sts	UDR0, r16
	ret



; Replace with your application code
start:
    ldi	r16, low(RAMEND)
	out	SPL, r16
	ldi	r16, high(RAMEND)
	out	SPH, r16
	cli
	call	initPorts
	call	initTmr0
	call	init_timer1
	call	initUsart0
	;inicializo variables
	ldi	r16, 0x80
	sts	maskLeds, r16
	sts	heartbeat, r16
	ldi	r16, 0x00
	sts distanceMs+1, r16
	sts distanceMs, r16
	sts	maskLeds+1, r16
	sts	heartbeat+1, r16
	sts	counter, r16
	sts	counter+1, r16
	sts	headerRX, r16
	sts	indexRXr, r16
	sts	indexRXw, r16
	sts	indexTXr, r16
	sts	indexTXw, r16
	ldi	r16, 5
	sts	time10ms, r16
	ldi	r16, 10
	sts	time100ms, r16
	in	r16, PINB
	//sbi	GPIOR0, LASTSTATEBTN
	cbi GPIOR0, MIDIENDO
	;fin inicializacion
	sei
loop:
	sbis	GPIOR0, IS10MS	
	rjmp	testIfKey
	cbi		GPIOR0, IS10MS
	sbic	GPIOR0, MIDIENDO
	call	do100ms
	sbic	GPIOR0, CALCULAR
	call	calculo
testIfKey:
	sbis	GPIOR0, ISNEWBTN
	rjmp	testNewCMD
testNewCMD:
	sbis	GPIOR0, DATAREADY
	rjmp	testRXData
	cbi		GPIOR0, DATAREADY
	call	DecodeCMD
testRXData:
	lds	r16, indexRXw
	lds	r17, indexRXr
	cpse	r16, r17
	call	DecodeHeader
	nop
testTXData:
	lds	r16, indexTXw
	lds	r17, indexTXr
	cpse	r16, r17
	call	txData
	nop
	rjmp	loop

calculo:
	cbi GPIOR0, CALCULAR

	lds r20, COUNTON
	lds r21, COUNTOFF
	lds r22, COUNTON+1
	lds r23, COUNTOFF+1

	sub r21,r20
	sbc r23, r22

	sts distanceMs+1, r23
	sts distanceMs, r21
	rjmp testIfKey