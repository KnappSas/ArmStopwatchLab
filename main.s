
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
	
text	DCB	"Stoppuhr\n\r",0
timecode DCB "00:00.00\n\r",0

;********************************************
; Code section, aligned on 8-byte boundery
;********************************************

	AREA |.text|, CODE, READONLY, ALIGN = 3

;--------------------------------------------

lastTimer 		RN 8
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
		bl timerinit		; Initialize the timer       TODO: DIESER PISSER KOMMT SPÄTER >8-(
INITLOOP
		bl displayTime
		mov r0, #7			; RUNNING Key
		bl checkKey
		cmp r0, #1
		bne INITLOOP
		b RUNNING
		mov r0, #1
		mov r1, #1
		bl setLED	
INITEND
		
RUNNING
		bl checkTimer
		bl displayTime
		b RUNNING
RUNNINGEND

forever	b	forever		; nowhere to retun if main ends		
		ENDP

displayTime	PROC
		push{r0, r1, r2, lr}	

		mov r1, #1000			; berechne 10er-Stellen

		udiv r2, totalTime, r1
		mul r3, r2, r1
		sub r3, totalTime, r3	; berechne rest
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
		udiv r0, r0 ,r2
		cmp lastTimer, r0
		bhi overflow
		sub r1, r0, lastTimer	
		add totalTime, totalTime, r1	;add difference between newTime and lastTime to totalTime
		b checkTimerEnd
overflow
		mov r2, #6000
		sub r1, r2, lastTimer
		add totalTime, totalTime, r1
		add totalTime, totalTime, r0
	
checkTimerEnd 
		mov lastTimer, r0	
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
		mov r0, #0
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
