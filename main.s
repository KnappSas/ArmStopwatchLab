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
	
LED19 equ 1
LED20 equ 2

totalTime		RN 9

;--------------------------------------------

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

INIT
		mov r0, #0xffff		; turn off all LEDs
		ldr r1, =GPIO_G_CLR
		strh r0, [r1]
INITLOOP
		bl displayTime
		mov r0, #RunningKey	
		bl checkKey
		cmp r0, #1
		bne INITLOOP
		b RUNNINGINIT	
INITEND
		
RUNNINGINIT
		bl timerinit		; Initialize the timer
RUNNING
		mov r0, #LED20
		mov r1, #1
		bl setLED 
RUNNINGLOOP
		bl checkTimer
		bl displayTime
		mov r0, #HoldKey	
		bl checkKey
		cmp r0, #0
		beq HOLD
		b RUNNINGLOOP
RUNNINGEND

HOLD
HOLDLOOP
		bl checkTimer
		mov r0, #RunningKey	
		bl checkKey
		cmp r0, #0
		beq RUNNINGLOOP
		b HOLDLOOP
HOLDLOOPEND


forever	b	forever		; nowhere to retun if main ends		
		ENDP

displayTime	PROC
		push{r0, r1, r2, lr}	

		mov r1, #1000			; berechne 10er-Stellen

		udiv r2, totalTime, r1
		mul r3, r2, r1
		sub r3, totalTime, r3	; berechne Rest
		add r0, r2, #0x30
		
		ldr r2, =timecode
		strb r0, [r2, #3]
		
		mov r1, #100			; berechne 1er-Stellen
		mov r0, r3
		udiv r2, r0, r1
		mul r3, r2, r1
		sub r3, r0, r3
		add r0, r2, #0x30
	
		ldr r2, =timecode
		strb r0, [r2, #4]
		
		mov r1, #10				; berechne 10er-Hundertstel
		mov r0, r3
		udiv r2, r0, r1
		mul r3, r2, r1
		sub r3, r0, r3
		add r0, r2, #0x30

		ldr r2, =timecode
		strb r0, [r2, #6]

		add r0, r3, #0x30		; berechne 1er-Hundertstel
		ldr r2, =timecode
		strb r0, [r2, #7]
		
		;ldr r2, = timecode
		;ldrb r3, [r2, #3]
		;cmp r3, #0x36			; ASCII 6
		;beq secondsOverflow
		;b secondsOverflowEnd
;secondsOverflow
		;ldrb r3, [r2, #1]
		;add r3, #1
		;strb r3, [r2, #1]
		
		;mov r4, #0x30
		;strb r4, [r2, #3]

		;cmp r3, #0x30
		;beq minutesOverflow		; Um Zehnerstellen hochzuzählen
		;b secondsOverflowEnd
;minutesOverflow
		;ldrb r3, [r2, #0]
		;add r3, #1
		;strb r3, [r2, #0]
;secondsOverflowEnd

		mov r0, #8
		mov r1, #7
		bl TFT_gotoxy
		
		ldr r0,=timecode
		bl	TFT_puts		; call TFT output method	
		pop{r0,r1, r2, lr}
		bx lr 
		
		ENDP

checkTimer PROC
		push{r0-r2,lr}
		
		bl getTimeStamp		; load newTime in r0
		
		mov r2, #100
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
		cmp r2,	#0xff			; if xor result if 0xff the key is down
		beq keyDown				
		
		b checkKeyEnd
keyDown
		mov r0, #1
checkKeyEnd

		pop	{r1,r2}
		bx lr
		ENDP
			
			
setLED	PROC
		push {r2,r3}
		mov r2, #1
		lsl r2,r2,r0
		
		cmp	r1,#1
		beq set
		
		ldr r3, =GPIO_G_CLR
		strh r2, [r3]

		b setLEDend

set		ldr r3, =GPIO_G_SET
		strh r2, [r3]
		
setLEDend	pop {r1,r2}
		bx lr
		
		ENDP
			
			
		ALIGN
       
		END