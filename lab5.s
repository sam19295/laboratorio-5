; Archivo: main.s
; Dispositivo: PIC16F887
; Autor: Melanie Samayoa
; Compilador: pic-as (v2.30), MPLAB v5.40
; Programa: Contadores utilizando interrupciones y Pullups
; Hardware: LEDS en el puerto D, 7 segmentos en el puerto A y C,  y
;	    Botones en el puerto B
    
; Creado: 22 feb, 2022
; Última modificación: 22 feb, 2022
    
PROCESSOR 16F887
    
; PIC16F887 Configuration Bit Settings

; Assembly source line config statements

; CONFIG1
  CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
  CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
  CONFIG  PWRTE = OFF            ; Power-up Timer Enable bit (PWRT enabled)
  CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
  CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
  CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
  CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
  CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
  CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
  CONFIG  LVP = OFF             ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
  CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
  CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)

// config statements should precede project file includes.
#include <xc.inc>
    
; -------------------------------- macros -------------------------------------
  
  RESET_TMR0 MACRO	    // macros para reiniciar el valor del timer
    BANKSEL TMR0	    // banco 00	 
    MOVLW   217
    MOVWF   TMR0	    // limpiar bandera	    
    BCF	    T0IF	    
    ENDM
  
; -------------------------------- variables de memoria  -------------------------------------

 UP EQU 0
 DOWN EQU 1

PSECT udata_bank0
    cont:		DS 1	
    centenas:		DS 1
    decenas:		DS 1
    unidades:		DS 1
    banderas:		DS 1	
    display:		DS 3	
    
; -------------------------------- status para interrupciones  -------------------------------------

PSECT udata_shr		    ; Memoria compartida
    tempw:		DS 1
    temp_status:	DS 1
    
    
    
PSECT resVect, class=CODE, abs, delta=2
		   
; -------------------------------- vector reset  -------------------------------------
ORG 00h	
resetVec:
    PAGESEL main
    GOTO    main
    
PSECT intVect, class=CODE, abs, delta=2
			
; -------------------------------- vector int  -------------------------------------
ORG 04h	
push:
    MOVWF   tempw		
    SWAPF   STATUS, W
    MOVWF   temp_status		
    
isr:
    
    BTFSC   RBIF		; Fue interrupción del PORTB? No=0 Si=1
    CALL    int_portb		; Si -> Subrutina de interrupción de PORTB
    BANKSEL PORTA
    BTFSC   T0IF		; Fue interrupción del TMR0? No=0 Si=1
    CALL    int_tmr0

pop:
    SWAPF   temp_status, W  
    MOVWF   STATUS		
    SWAPF   tempw, F	    
    SWAPF   tempw, W		
    RETFIE			
    
    
PSECT code, delta=2, abs
ORG 100h			
; -------------------------------- configuracion -------------------------------------
main:
    CALL    configio		
    CALL    configwatch	
    CALL    configtmr0		
    CALL    configint	
    CALL    configcb
    BANKSEL PORTA		

; -------------------------------- loop principal -------------------------------------

loop:
    CALL valordec	    
    CALL obcent
    GOTO  loop
    
; -------------------------------- subrutinas  -------------------------------------

configwatch:
    BANKSEL OSCCON		
    BSF	    OSCCON, 0	
    BSF	    OSCCON, 6
    BSF	    OSCCON, 5
    BCF	    OSCCON, 4		; IRCF<2:0> -> 110 4MHz
    RETURN
    
configtmr0:
    BANKSEL OPTION_REG		
    BCF	    OPTION_REG, 5	
    BCF	    OPTION_REG, 3
    BSF	    OPTION_REG, 2
    BSF	    OPTION_REG, 1
    BSF	    OPTION_REG, 0
    
    RESET_TMR0 		
    RETURN 
    
configio:
    BANKSEL ANSEL
    CLRF    ANSEL
    CLRF    ANSELH
    
    BANKSEL TRISA	
    BSF	    TRISB, UP	
    BSF	    TRISB, DOWN	
    
    CLRF    TRISA
    CLRF    TRISC
    CLRF    TRISD
    
    BCF OPTION_REG, 7
    BSF	WPUB, UP
    BSF WPUB, DOWN
    
    BANKSEL PORTA
    CLRF    PORTA
    CLRF    PORTB
    CLRF    PORTC
    CLRF    PORTD
    CLRF    centenas
    CLRF    decenas
    CLRF    unidades
    CLRF    banderas
   				
    RETURN
       
configint:		
    BANKSEL INTCON
    BSF	    GIE
    BSF	    RBIF
    BCF	    RBIF
    BSF	    T0IE		
    BCF	    T0IF		
		
    RETURN
    
configcb:
    BANKSEL TRISA
    BSF	    IOCB, UP
    BSF	    IOCB, DOWN
    
    BANKSEL PORTA
    MOVF    PORTB, W
    BCF	    RBIF
    
    RETURN

int_portb:
    BANKSEL PORTA
    BTFSS   PORTB, UP
    INCF    PORTA
    BTFSS   PORTB, DOWN
    DECF    PORTA
    BCF	    RBIF
    
    RETURN
    
int_tmr0:
    RESET_TMR0 		
    CALL    mostrar_valor	
    RETURN
    
valordec:
    MOVF unidades, W
    CALL tabla
    MOVWF display
    
    MOVF decenas, W
    CALL tabla
    MOVWF display+1
    
    MOVF centenas, W
    CALL tabla
    MOVWF display+2

    
mostrar_valor:
    BCF	    PORTD, 0		
    BCF	    PORTD, 1
    BCF	    PORTD, 2
    
    BTFSC   banderas, 0		
    GOTO    display3
    
    BTFSC   banderas, 1
    GOTO    display2
    
    BTFSC   banderas, 2
    GOTO    display1
    
    display1:			
	MOVF    display, W	
	MOVWF   PORTC		
	BSF	PORTD, 2	
	BCF	banderas, 2
	BSF	banderas, 1
	
    RETURN

    display2:
	MOVF    display+1, W	
	MOVWF   PORTC		
	BSF	PORTD, 1	
	BCF	banderas, 1
	BSF	banderas, 0
	
    RETURN
    
   display3:
	MOVF	display+2, W
	MOVWF	PORTC
	BSF	PORTD, 0
	BCF	banderas, 0
	BSF	banderas, 2

	
obcent:
    CLRF    centenas
    CLRF    decenas
    CLRF    unidades
    
    MOVF    PORTA, W
    MOVWF   cont
    MOVLW   100
    SUBWF   cont, F
    INCF    centenas
    BTFSC   STATUS, 0
    
    GOTO    $-4
    DECF    centenas
    
    MOVLW   100
    ADDWF   cont, F
    CALL    obdec
    
    RETURN

obdec:
    MOVLW   10
    SUBWF   cont, F
    INCF    decenas
    BTFSC   STATUS, 0
    
    GOTO    $-4
    DECF    decenas
    
    MOVLW   10
    ADDWF   cont, F
    CALL    obuni
    
    RETURN
 
obuni:
    MOVLW   1
    SUBWF   cont, F
    INCF    unidades
    BTFSC   STATUS, 0
    
    GOTO    $-4
    DECF    unidades
    
    MOVLW   1
    ADDWF   cont, F
    
    RETURN
    
ORG 200h
    
 ; -------------------------------- tabla -------------------------------------
   
tabla:
    
    CLRF    PCLATH		
    BSF	    PCLATH, 1	
    ANDLW   0x0F		
    ADDWF   PCL
    RETLW   00111111B	;0
    RETLW   00000110B	;1
    RETLW   01011011B	;2
    RETLW   01001111B	;3
    RETLW   01100110B	;4
    RETLW   01101101B	;5
    RETLW   01111101B	;6
    RETLW   00000111B	;7
    RETLW   01111111B	;8
    RETLW   01101111B	;9
    RETLW   01110111B	;A
    RETLW   01111100B	;B
    RETLW   00111001B	;C
    RETLW   01011110B	;D
    RETLW   01111001B	;E
    RETLW   01110001B	;F
    
END