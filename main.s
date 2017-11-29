;******************** (C) COPYRIGHT HAW-Hamburg ********************************
;* File Name          : main.s
;* Author             : Alfred Lohmann
;* Author             : Tobias Jaehnichen	
;* Version            : V2.0
;* Date               : 13.04.2017
;* Description        : This is a simple main. 
;					  : It reads the ADC value and displays the most significant 8 bits
;					  : on the LEDs D13 to D20.
;					  : 
;					  : Change this main according to the lab-task.
;
;*******************************************************************************

	EXTERN Init_TI_Board		; Initialize the serial line
	;EXTERN ADC3_CH7_DMA_Config  ; Initialize the ADC
	EXTERN	initHW				; Init Timer
	EXTERN 	timer				; timer
	;EXTERN	puts				; C output function
	EXTERN TFT_puts				; TFT output function
	EXTERN TFT_cls				; TFT clear function
	EXTERN TFT_gotoxy      		; TFT goto x y function  
	;EXTERN Delay				; Delay (ms) function
	EXTERN GPIO_G_SET			; Set output-LEDs
	EXTERN GPIO_G_CLR			; Clear output-LEDs
	EXTERN GPIO_G_PIN			; Output-LEDs status
	EXTERN GPIO_E_PIN			; Button status
	;EXTERN ADC3_DR				; ADC Value (ADC3_CH7_DMA_Config has to be called before)

;********************************************
; Data section, aligned on 4-byte boundery
;********************************************
	
	AREA MyData, DATA, align = 2
	
timecode	DCB	"00:00:00",0

;********************************************
; Code section, aligned on 8-byte boundery
;********************************************

	AREA MyCode, CODE, READONLY, ALIGN = 2

;--------------------------------------------
; main subroutine
;--------------------------------------------
	EXPORT main [CODE]
		
main	PROC

		bl	Init_TI_Board	; Initialize the serial line to TTY
							; for compatability to out TI-C-Board
		bl initHW
		
		ldr r10, =timer
superloop	
		bl checktimer

		ldr r0, =Keys		; check if INIT key is toggled
		ldrb r0, [r0]
		bl checkkey
		ldr r0, =INIT
		strb r1, [r0]
		
		ldr r0, =Keys		; check if RUNNING key is toggled
		ldrb r0, [r0, #1]
		bl checkkey
		ldr r0, =RUNNING
		strb r1, [r0]

		ldr r0, =Keys		; check if HOLD key is toggled
		ldrb r0, [r0, #2]
		bl checkkey
		ldr r0, =HOLD
		strb r1, [r0]
		
		mov r0, #2_10000000 ; LED D19
		; mov r1, ...
		bl setled
		mov r0, #2_01000000 ; LED D20
		; mov r1, ...
		bl setled
		
		bl displaytime
		B	superloop				
		ENDP

forever B forever			; nowhere to return if main ends

checkkey PROC
		push{r1,lr}
		ldr r1, =GPIO_E_PIN
		ldrh r1, [r1]
		cmp r0, r1
		mov r1, #0
		bne IF_KEY_DOWN
		mov r1, #1
IF_KEY_DOWN		
		pop{r1,lr}
		bx lr
		ENDP

setled	PROC
		push{r1,lr}
		strh 	r5, [gpio_clr]					; LEDs loeschen
		strh 	r0, [gpio_set]					; Ausgabe Bitmuster
		pop{r1,lr}
		bx lr
		ENDP

displaytime	PROC
		push{r0,lr}	
		;TODO: umrechnung von Hundertstel in Minuten etc
		mov r0, #16
		mov r1, #8
		bl  TFT_gotoxy 	; string mittig platzieren mit r0, r1 als parameter
		bl	TFT_puts			; call TFT output method
		pop{r0,lr}
		ENDP

; r5 ist Gesamtzeit
; r6 ist alter timerstand
; r7 ist neuer timerstand
checktimer PROC
		push{r1-r5, lr}
		ldrh r7, [r10]		; Neuen Timerstand in r1 laden
		cmp r7, r6			; Vergleich neuer Stand mit altem
		blt overflow		; Wenn neuer Stand niedriger als neuer -> overflow
		sub r7, r6			; Differenz zwischen neuem und altem Stand
		add r5, r7			; Differenz zu Gesamtzeit hinzufügen
		mov r6, r7			; Neuen Stand aktualisieren	
		b retchecktimer
overflow		
		mov r3, #65535
		sub r3, r6		; Differenz zwischen altem Stand und Overflow
		add r5, r3		; Differenz zur Gesamtzeit hinzufügen
		add r5, r7		; Zeit zwischen Overflow und neuem Stand
		mov r6, r7		; Neuen Stand aktualisieren
retchecktimer
		pop{r1-r5,lr}	
			ENDP

		ALIGN
       
		END