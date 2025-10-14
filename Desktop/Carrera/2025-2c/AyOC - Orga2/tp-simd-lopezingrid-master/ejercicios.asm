; Hace que los accesos a memoria por defecto se compilen como [rip + offset]
; en lugar de [offset_desde_el_0x0].
;
; Ver https://www.nasm.us/doc/nasmdoc7.html#section-7.2.1 para más información
DEFAULT REL

; El valor a poner en los campos `<ejercicio>_hecho` una vez estén completados
TRUE  EQU 1
; El valor a dejar en los campos `<ejercicio>_hecho` hasta que estén completados
FALSE EQU 0
 
; Offsets a utilizar durante la resolución del ejercicio.
PARTICLES_COUNT_OFFSET    EQU 56 ; ¡COMPLETAR!	8
PARTICLES_CAPACITY_OFFSET EQU 64 ; ¡COMPLETAR!	8
PARTICLES_POS_OFFSET      EQU 72 ; ¡COMPLETAR!	8
PARTICLES_COLOR_OFFSET    EQU 80 ; ¡COMPLETAR!	8
PARTICLES_SIZE_OFFSET     EQU 88 ; ¡COMPLETAR!	8
PARTICLES_VEL_OFFSET      EQU 96 ; ¡COMPLETAR!	8

section .rodata

; La descripción de lo hecho y lo por completar de la implementación en C del
; TP.
global ej_asm
ej_asm:
  .posiciones_hecho: db TRUE
  .tamanios_hecho:   db TRUE
  .colores_hecho:    db TRUE
  .orbitar_hecho:    db FALSE
  ALIGN 8
  .posiciones: dq ej_posiciones_asm
  .tamanios:   dq ej_tamanios_asm
  .colores:    dq ej_colores_asm
  .orbitar:    dq ej_orbitar_asm

; Máscaras y valores que puede ser útil cargar en registros vectoriales.
;
; ¡Agregá otras que veas necesarias!
ALIGN 16
ceros:      dd  0.0,    0.0,     0.0,    0.0
unos:       dd  1.0,    1.0,     1.0,    1.0

section .text

; Actualiza las posiciones de las partículas de acuerdo a la fuerza de
; gravedad y la velocidad de cada una.
;
; Una partícula con posición `p` y velocidad `v` que se encuentra sujeta a
; una fuerza de gravedad `g` observa lo siguiente:
; ```
; p := (p.x + v.x, p.y + v.y)
; v := (v.x + g.x, v.y + g.y)
; ```
;
; void ej_posiciones(emitter_t* emitter, vec2_t* gravedad);
ej_posiciones_asm:
	;prologo
	push rbp 
	mov rbp, rsp

	;rdi: puntero a emitter_t* emitter (arg 1)
	;rsi: puntero a vec2_t* gravedad (arg 2)
	mov rcx, [rdi + PARTICLES_COUNT_OFFSET]		; total particulas
	mov rdx, [rdi + PARTICLES_POS_OFFSET]		; puntero a posiciones
	mov r8,  [rdi + PARTICLES_VEL_OFFSET]		; puntero a velocities

	movq xmm0, [rsi]			;carga la gravedad xmm0 = [0, 0, g.y, g.x]
	movlhps xmm0, xmm0			;extiendo a 4
        
    xor r9, r9 		;indice
    
	.loop:
		cmp r9, rcx 		;comparo el indice con la cant total de particulas
		jae .fin

        movaps xmm1, [rdx + r9*8]		;carga de 16 bytes de posiciones	[p.y, p.x, p.y, p.x]
		movaps xmm2, [r8 + r9*8]		;carga de 16 bytes de velocidades	[v.y, v.x, v.y, v.x]
			
		addps xmm1, xmm2 	;p = p + v
		addps xmm2, xmm0	;v = v + g

		;almacenamiento de 2 particulas (16 bytes)
		movaps [rdx + r9*8], xmm1 	;guarda las nuevas posiciones
		movaps [r8 + r9*8], xmm2		;guarda las nuevas velocidades

		add r9, 2
		jmp .loop 

	.fin: 
		pop rbp 
		ret

; Actualiza los tamaños de las partículas de acuerdo a la configuración dada.
;
; Una partícula con tamaño `s` y una configuración `(a, b, c)` observa lo
; siguiente:
; ```
; si c <= s:
;   s := s * a - b
; sino:
;   s := s - b
; ```
;

;Teniendo en cuenta que un if...else... es equivalente a:
; (c <= Ti)*(a-1)*Ti+Ti-b 
; siendo que segun si se cumple el condicional (True (1) o False (0)), es que se multiplica o no por "a" 

; void ej_tamanios(emitter_t* emitter, float a, float b, float c);
ej_tamanios_asm:
	;rdi: puntero a emitter
	;xmm0: float a 
	;xmm1: float b
	;xmm2: float c

	push rbp 
	mov rbp, rsp 

	mov r8, [rdi + PARTICLES_COUNT_OFFSET]		;total particulas
	mov r9, [rdi + PARTICLES_SIZE_OFFSET]		;puntero a tamaños

	xor r10, r10 		;indice 

¡	shufps xmm0, xmm0, 0	;[a,a,a,a]
	subps xmm0, [unos] ; [a-1, a-1, a-1, a-1]

	shufps xmm1, xmm1, 0	;[b, b, b, b]
	shufps xmm2, xmm2, 0	;[c, c, c, c]


	.loop: 
		cmp r10, r8 	;si indice >= particulas, termina el ciclo
		jae .fin 

		movups xmm4, [r9 + 4 * r10] 	;xmm4 = [t1, t2, t3, t4]

		movaps xmm8, xmm4 	;xmm8 = xmm4 = [t1, t2, t3, t4]
		movaps xmm9, xmm4 	;xmm9 = xmm4 = [t1, t2, t3, t4]

		mulps xmm8, xmm0 	;xmm8 = [t1*(a-1), t2*(a-1), t3*(a-1), t4*(a-1)]

		;hago el compare:
		CMPPS xmm9, xmm2, 5		; xmm4 >= xmm2; c <= t
		; multiplico por el comparador
		mulps xmm8, xmm9 	; [comp*t1*(a-1), comp*t2*(a-1), comp*t3*(a-1), comp*t4*(a-1)]
		addps xmm8, xmm4	;xmm4 = [t1*(a-1)+t1, t2*(a-2)+t2, t3*(a-3)+t3, t4*(a-4)+t4]
		subps xmm8, xmm1 	;xmm4 = [t1*(a-1)+t1-b, t2*(a-2)+t2-b, t3*(a-3)+t3-b, t4*(a-4)+t4-b] 

		movups [r9+4*r10], xmm8	;xmm4 = [t1, t2, t3, t4]

		; | FF | 00 | 00 | FF
		add r10, 4
		jmp .loop 

	.fin:
		pop rbp 
		ret

; Actualiza los colores de las partículas de acuerdo al delta de color
; proporcionado.
;
; Una partícula con color `(R, G, B, A)` ante un delta `(dR, dG, dB, dA)`
; observa el siguiente cambio:
; ```
; R = R - dR
; G = G - dG
; B = B - dB
; A = A - dA
; si R < 0:
;   R = 0
; si G < 0:
;   G = 0
; si B < 0:
;   B = 0
; si A < 0:
;   A = 0
; ```
;
; void ej_colores(emitter_t* emitter, SDL_Color a_restar);
ej_colores_asm:
	;rdi: emitter 
	;rsi: a_restar
	push rbp 
	mov rbp, rsp ;mmm

		mov r8, [rdi + PARTICLES_COUNT_OFFSET]		;total particulas
		mov r9, [rdi + PARTICLES_COLOR_OFFSET] 		;puntero a los colores a restar RGBA

		xor r10, r10 	;indice

		movd xmm0, esi 		; xmm0 = [?, ?, ?, arestar]
		shufps xmm0, xmm0, 0 ; xmm0 = [arestar, arestar, arestar, arestar] valores de a_restar

		.loop: 
			cmp r10, r8 	
			jae .fin 
			movups xmm2, [r9+4*r10]

			psubusb xmm2, xmm0 ;  .  
			movups [r9+4*r10], xmm2

 	 		add r10, 4
			jmp .loop 
		.fin:
			pop rbp
			ret

; Calcula un campo de fuerza y lo aplica a cada una de las partículas,
; haciendo que tracen órbitas.
;
; La implementación ya está dada y se tiene en el enunciado una versión más
; "matemática" en caso de que sea de ayuda.
;
; El ejercicio es implementar una versión del código de ejemplo que utilice
; SIMD en lugar de operaciones escalares.
;
; void ej_orbitar(emitter_t* emitter, vec2_t* start, vec2_t* end, float r);
ej_orbitar_asm:
	ret
