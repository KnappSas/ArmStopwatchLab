;******************** (C) COPYRIGHT HAW-Hamburg ********************************
;* File Name          : main.s
;* Author             : Alfred Lohmann
;* Author             : Tobias Jaehnichen	
;* Version            : V2.0
;* Date               : 23.04.2017
;* Description        : This is a simple main.
;					  : The output is send to UART 1. Open Serial Window when 
;					  : when debugging. Select UART #1 in Serial Window selection.
;					  :
;					  : Replace this main with yours.
;
;*******************************************************************************

	EXTERN Init_TI_Board		; Initialize the serial line
	EXTERN ADC3_CH7_DMA_Config  ; Initialize the ADC
	;EXTERN	initHW				; Init Timer
	EXTERN	puts				; C output function
	EXTERN	TFT_puts			; TFT output function
	EXTERN  TFT_cls				; TFT clear function
	EXTERN  TFT_gotoxy      	; TFT goto x y function  
	EXTERN  Delay				; Delay (ms) function
	EXTERN GPIO_G_SET			; Set output-LEDs
	EXTERN GPIO_G_CLR			; Clear output-LEDs
	EXTERN GPIO_G_PIN			; Output-LEDs status
	EXTERN GPIO_E_PIN			; Button status
	EXTERN ADC3_DR				; ADC Value (ADC3_CH7_DMA_Config has to be called before)
		
	EXTERN timerinit			; New Timer(100ms)
	EXTERN getTimeStamp
	EXTERN timerReset

;********************************************
; Data section, aligned on 4-byte boundery
;********************************************
	
	AREA MyData, DATA, align = 2
	
text	DCB	"Stoppuhr.\n\r",0
timecode DCB "00:00.00\n",0

;********************************************
; Code section, aligned on 8-byte boundery
;********************************************

	AREA |.text|, CODE, READONLY, ALIGN = 3

;--------------------------------------------

RunningKey equ 7
HoldKey equ 6
InitKey equ 5
	
LED19 equ 6
LED20 equ 7

totalTime	RN 9
lastTime 	RN 8

;--------------------------------------------
; main subroutine
;--------------------------------------------
	EXPORT main [CODE]
	
main	PROC

		bl	Init_TI_Board	; Initialize the serial line to TTY
							; for compatability to out TI-C-Board
		;BL	initHW			; Timer init
				
		ldr r0,=text
		bl	TFT_puts		; call TFT output method
		
		
		bl timerinit
		
INIT
		bl clearAllLEDs
		bl timerReset
		mov totalTime, #0
		mov lastTime, #0
		bl clearMinutes
		bl displayTime
INITLOOP
		mov r0, #RunningKey	
		bl checkKey
		cmp r0, #1
		bne INITLOOP
		bl timerReset	
		b RUNNING	
INITEND
				
RUNNING
		mov r0, #LED20
		mov r1, #1
		bl setLED
RUNNINGLOOP
		bl checkTimer
		bl displayTime
		mov r0, #HoldKey	
		bl checkKey
		cmp r0, #1			; if holdKey down, jump to Hold
		beq HOLD
		mov r0, #InitKey	; if initKey down, jump to init
		bl checkKey
		cmp r0, #1
		beq INIT
		b RUNNINGLOOP
RUNNINGEND

HOLD
		mov r0, #LED19
		mov r1, #1
		bl setLED 
HOLDLOOP
		bl checkTimer
		mov r0, #RunningKey	
		bl checkKey
		cmp r0, #1
		beq HOLDLOOPEND
		mov r0, #InitKey	
		bl checkKey
		cmp r0, #1
		beq INIT
		b HOLDLOOP
HOLDLOOPEND
		bl clearAllLEDs
		b RUNNING

forever	b	forever		; nowhere to retun if main ends		
		ENDP

clearAllLEDs PROC
		push{r0-r2, lr}
		mov r0, #0xffff		; turn off all LEDs
		ldr r1, =GPIO_G_CLR
		strh r0, [r1]
		pop{r0-r2, lr}
		bx lr
		ENDP

clearMinutes PROC
		push{r0-r2, lr}
		ldr r2, =timecode
		mov r0, #0x30
		strb r0, [r2]
		strb r0, [r2, #1]
		strb r0, [r2, #3]
		strb r0, [r2, #4]
		strb r0, [r2, #6]
		strb r0, [r2, #7]
		pop{r0-r2, lr}
		bx lr
		ENDP

;
; @param r1 dividend for udiv
; @param r3 number to convert
; @param r4 digit position
; @return remainder is stored in r3
;
convertToDigitAndStore PROC
		push{r0,r1,r2,r4}
		mov r0, r3
		udiv r2, r3, r1		; r3 / r1
		mul r3, r2, r1		; r2 * r1 = r3
		sub r3, r0, r3		; calculate remainder, store in r3
		add r0, r2, #0x30	; offset for ASCII-Digit
		ldr r2, =timecode	
		strb r0, [r2, r4]	
		pop{r0,r1,r2,r4}
		bx lr
		ENDP

displayTime	PROC
		push{r0, r1, r2, lr}	

		mov r1, #1000				; berechne 10er-Stellen
		mov r3, totalTime
		mov r4, #3
		bl convertToDigitAndStore
		mov r1, #100				; berechne 1er-Stellen
		mov r4, #4
		bl convertToDigitAndStore
		mov r1, #10					; berechne 10er-Hundertstel
		mov r4, #6
		bl convertToDigitAndStore
		mov r1, #1					; berechne 1er-Hundertstel
		mov r4, #7
		bl convertToDigitAndStore
		
if01	cmp totalTime, lastTime		; check if overflow happened
		bhs else01
then01	ldr r2, =timecode
		ldrb r0, [r2,#1]
		add r0, #1
if02	cmp r0, #0x3A				; Hex-value after 0x39 which is digit 9
		bne else02
then02	mov r0, #0x30
		strb r0, [r2,#1]
		ldrb r0, [r2]
		add r0, #1
		strb r0, [r2]				; write new added minute value at tens position
		b else01
else02
		strb r0, [r2,#1]			; write new added minute units value
endIf02
else01
		mov lastTime, totalTime
endIf01
									; TFT-Output	
		mov r0, #8					
		mov r1, #7
		bl TFT_gotoxy				
		ldr r0,=timecode
		bl	TFT_puts				; call TFT output method	
		pop{r0,r1, r2, lr}
		bx lr 
		
		ENDP

checkTimer PROC
		push{r0-r2,lr}
		
		bl getTimeStamp		; load newTime in r0
		mov r2, #100		; get rid of unnecessary digits
		udiv totalTime, r0 ,r2	
		pop{r0-r2,lr}
		
		bx lr
		
		ENDP

; parameter r0 holds which key should be checked
checkKey	PROC
		push {r1,r2}
		ldr r1, =GPIO_E_PIN 	; load adress of GPIO_E_PIN
		ldr r1, [r1]			
		mov r2, #1				
		lsl r2, r2, r0			; compare value at GPIO_E_PIN with LSL 1 of r0
		eor r2,r1
if03	cmp r2,	#0xff			; if xor result if 0xff the key is down
		beq then03				
		
		b endIf03
then03
		mov r0, #1
endIf03
		pop	{r1,r2}
		bx lr
		ENDP
			
			
setLED	PROC
		push {r2,r3}
		mov r2, #1
		lsl r2,r2,r0
		
if04	cmp	r1,#1
		beq then04
		
		ldr r3, =GPIO_G_CLR
		strh r2, [r3]

		b endIf04

then04	ldr r3, =GPIO_G_SET
		strh r2, [r3]
		
endIf04	pop {r1,r2}
		bx lr
		
		ENDP
			
			
		ALIGN
       
		END