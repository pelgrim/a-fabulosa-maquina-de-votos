;A Fabulosa Maquina de Votos

;variaveis 'core'
total_votos equ 30h
entrada_valida equ 31h
entrada_codificada equ 32h
voto_a equ 41h
voto_b equ 42h
voto_c equ 43h
voto_d equ 44h
voto_e equ 45h
voto_f equ 46h
escolhido equ 34h
votos equ 35h
delay equ 36h

;variaveis debouncer
debouncer_counter equ 37h
entrada_atual equ 38h
entrada equ 39h

;variaveis lcd
lcd_buffer equ 3ah
lcd_pos equ 3bh
lcd_entrada   equ p3
lcd_porta_7   equ p3.7
lcd_e  equ p0.0
lcd_rs equ p0.1
lcd_rw equ p0.2


org 0
  ljmp main

org 0bh
  mov th0,#3Ch
  mov tl0,#0AFh
  ljmp debouncer

org 0050h

debouncer:
  push acc
  djnz debouncer_counter,debouncer_delay
  mov debouncer_counter,#05H
  mov a,entrada_atual
  mov entrada_atual,p1
  anl a,entrada_atual
  mov entrada,a
  mov entrada,entrada ; Aqui eh Deus agindo
  debouncer_delay:

  nop
  pop acc
  reti


org 0200h
delayms:
  mov r7,#03h
  delay_estagio1:
    mov r6,#0a6h
    djnz r6,$
    djnz r7,delay_estagio1
    djnz delay,delayms
ret

lcd_busy:
  setb lcd_e
  clr lcd_rs
  setb lcd_rw
  check:
    clr lcd_e
    setb lcd_e ;Enable H->L
    mov delay, #1h
    acall delayms
    jb lcd_porta_7,check
  ret

lcd_cmd:
  mov lcd_entrada, lcd_buffer
  clr lcd_rs
  clr lcd_rw
  setb lcd_e
  clr lcd_e
  acall lcd_busy
  ret

lcd_data:
  mov a,#10h
  clr c
  subb a,lcd_pos
  jnz lcd_data_write
    mov a,lcd_buffer
    mov lcd_buffer,#0c0h
    acall lcd_cmd
    mov lcd_buffer,a
  lcd_data_write:
    mov lcd_entrada, lcd_buffer
    setb lcd_rs
    clr lcd_rw
    setb lcd_e
    clr lcd_e
    acall lcd_busy
    inc lcd_pos
  ret

lcd_clear:
  mov lcd_pos, #0h
  acall lcd_cmd
  mov lcd_buffer,#01h
  acall lcd_cmd
  mov lcd_buffer,#06h
  acall lcd_cmd
  mov lcd_buffer,#80h
  acall lcd_cmd
  ret

org 0300h
inicia_hardware:
  ;geral

  ;lcd
  mov lcd_entrada,#00h
  acall lcd_busy
  mov lcd_buffer, #38h
  acall lcd_cmd
  mov lcd_buffer, #38h
  acall lcd_cmd
  mov lcd_buffer, #38h
  acall lcd_cmd
  mov lcd_buffer, #0ch
  acall lcd_cmd
  acall lcd_clear

  ;debouncer (int0)
  mov debouncer_counter,#05H
  MOV P2,#00H
  MOV P1,#00H
  mov tmod,#01h
  mov th0,#3Ch
  mov tl0,#0AFh
  MOV IE,#82H
  MOV TCON,#10H
  ret

org 0400h

espera_entrada_zerada:
  mov a,entrada
  jnz espera_entrada_zerada
  ret

inicia_maquina:
  mov total_votos,#0h
  mov voto_a,#0h
  mov voto_b,#0h
  mov voto_c,#0h
  mov voto_d,#0h
  mov voto_e,#0h
  mov voto_f,#0h

  ;senha_inicio
  lcall mensagem_1
  acall espera_entrada_zerada
  mov p2,#0fh
  checa_senha_inicio:
    mov a,entrada
    jz checa_senha_inicio

  mov p2,#0f0h
  ret

voto_branco:
  lcall mensagem_3
  acall espera_entrada_zerada
  checa_escolha_branco:
    clr c
    mov a,entrada
    subb a,#01h
    jnz checa_cancela_branco
    inc total_votos ; caso confirme, contabiliza voto
    sjmp fim_voto_branco
    checa_cancela_branco:
      mov a,entrada
      jz checa_escolha_branco
    fim_voto_branco:
    ret


confirma_voto:
  acall espera_entrada_zerada
  lcall mensagem_3
  checa_confirma_voto:
    clr c
    mov a,entrada
    subb a,#01h
    jnz checa_cancela_voto
    mov a,#48h
    clr c
    subb a,entrada_codificada
    mov r0,a
    inc @r0
    inc total_votos
    sjmp fim_confirma_voto
  checa_cancela_voto:
    mov a,entrada
    subb a,#02h
    jnz checa_confirma_voto
  fim_confirma_voto:
  ret

votacao:
  acall espera_entrada_zerada
  lcall mensagem_2
  checa_escolha_votacao:

    ;termina votacao
    clr c
    mov a,entrada
    subb a,#85h
    jz votacao_fim

    ;voto em branco
    ;Para votar em branco, o usuario deve primeiro pressionar cancela
    ;e, em seguida, pressionar confirma.
    clr c
    mov a,entrada
    subb a,#02h
    jz voto_branco_primeiro_cancela

    ;aguarda entrada pra analisar, diminuindo processamento inutil
    mov a,entrada
    jz checa_escolha_votacao

    mov entrada_codificada,#1h
    mov entrada_valida,entrada

    CEDS: ;Codificador de Entrada por Divisoes Sucessivas

    ;O usuario precisa pressionar apenas um botao para votar.
    ;A entrada, em sua representacao numerica, nesse caso, precisa ser uma potencia de dois.
    ;Para generalizar a verificacao da entrada de acordo com a arquitetura do software,
    ;vamos armazenar nao a entrada em si, mas o expoente daquela potencia.
    ;O metodo adotado para extrair essa potencia e o de divisoes sucessivas por dois.
    ;A cada divisao, um contador, inicialmente zerado, deve ser incrementado, ate que o resultado
    ;da divisao seja 1. O conteudo do contador sera, obviamente, o expoente desejado.
    ;Caso em alguma divisao o resto igual a um, a rotina deve ser encerrada, pois mais de um botao
    ;foi pressionado.

      mov a,entrada_valida
      mov b,#2h
      div ab
      mov entrada_valida,a
      mov a,b
      jnz checa_escolha_votacao
      mov a,entrada_valida
      subb a,#01h
      jz incrementa_voto
      inc entrada_codificada ;em entrada_codificada fica armazenado o expoente
      sjmp CEDS
      incrementa_voto:
        acall confirma_voto
        sjmp votacao

    sjmp checa_escolha_votacao

  voto_branco_primeiro_cancela:
    acall voto_branco
    sjmp votacao

  votacao_fim:
  ret

finaliza:
  mov a,total_votos
  jz reinicia ; se ninguem votou, termina direto

  mov R7,#06h
  mov R0,#41h
  determina_escolhido:
    mov escolhido,R0
    mov votos,@R0
  compara_com_o_proximo:

    dec r7
    mov a,r7
    jz prepara_mensagem_resultado

    inc R0
    mov a,votos
    clr c
    subb a,@R0
    jc determina_escolhido
    sjmp compara_com_o_proximo

  prepara_mensagem_resultado:
    mov a,votos
    add a,#30h
    mov votos,a
    lcall mensagem_escolhido
    acall espera_entrada_zerada
    mov r7,#0ffh
    mov r6,#0ffh
    aguarda_para_reinicio:
      djnz r7, aguarda_pisca_leds
      djnz r6, aguarda_pisca_leds
      mov r7,#0ffh
      mov r6,#0ffh
      mov a,p2
      cpl a
      mov p2,a
      aguarda_pisca_leds:
      mov a,entrada
      jz aguarda_para_reinicio

  reinicia:
  ret

org 0500h
main:
  ;start hardware
  mov sp,#70h
  acall inicia_hardware
  acall inicia_maquina
  acall votacao
  acall finaliza
  sjmp main

org 1000h ;mensagens lcd

mensagem_1:
;maquina de votos
;nao iniciada

  lcall lcd_clear
  mov lcd_buffer,#04dh
  lcall lcd_data
  mov lcd_buffer,#061h
  lcall lcd_data
  mov lcd_buffer,#071h
  lcall lcd_data
  mov lcd_buffer,#075h
  lcall lcd_data
  mov lcd_buffer,#069h
  lcall lcd_data
  mov lcd_buffer,#06eh
  lcall lcd_data
  mov lcd_buffer,#061h
  lcall lcd_data
  mov lcd_buffer,#020h
  lcall lcd_data
  mov lcd_buffer,#064h
  lcall lcd_data
  mov lcd_buffer,#065h
  lcall lcd_data
  mov lcd_buffer,#020h
  lcall lcd_data
  mov lcd_buffer,#076h
  lcall lcd_data
  mov lcd_buffer,#06fh
  lcall lcd_data
  mov lcd_buffer,#074h
  lcall lcd_data
  mov lcd_buffer,#06fh
  lcall lcd_data
  mov lcd_buffer,#073h
  lcall lcd_data
  mov lcd_buffer,#020h
  lcall lcd_data
  mov lcd_buffer,#06eh
  lcall lcd_data
  mov lcd_buffer,#061h
  lcall lcd_data
  mov lcd_buffer,#06fh
  lcall lcd_data
  mov lcd_buffer,#020h
  lcall lcd_data
  mov lcd_buffer,#069h
  lcall lcd_data
  mov lcd_buffer,#06eh
  lcall lcd_data
  mov lcd_buffer,#069h
  lcall lcd_data
  mov lcd_buffer,#063h
  lcall lcd_data
  mov lcd_buffer,#069h
  lcall lcd_data
  mov lcd_buffer,#061h
  lcall lcd_data
  mov lcd_buffer,#064h
  lcall lcd_data
  mov lcd_buffer,#061h
  lcall lcd_data
  ret

mensagem_2:
;Votacao iniciada
;Escolha de A a F

  lcall lcd_clear
  mov lcd_buffer,#056h
  lcall lcd_data
  mov lcd_buffer,#06fh
  lcall lcd_data
  mov lcd_buffer,#074h
  lcall lcd_data
  mov lcd_buffer,#061h
  lcall lcd_data
  mov lcd_buffer,#063h
  lcall lcd_data
  mov lcd_buffer,#061h
  lcall lcd_data
  mov lcd_buffer,#06fh
  lcall lcd_data
  mov lcd_buffer,#020h
  lcall lcd_data
  mov lcd_buffer,#069h
  lcall lcd_data
  mov lcd_buffer,#06eh
  lcall lcd_data
  mov lcd_buffer,#069h
  lcall lcd_data
  mov lcd_buffer,#063h
  lcall lcd_data
  mov lcd_buffer,#069h
  lcall lcd_data
  mov lcd_buffer,#061h
  lcall lcd_data
  mov lcd_buffer,#064h
  lcall lcd_data
  mov lcd_buffer,#061h
  lcall lcd_data
  mov lcd_buffer,#045h
  lcall lcd_data
  mov lcd_buffer,#073h
  lcall lcd_data
  mov lcd_buffer,#063h
  lcall lcd_data
  mov lcd_buffer,#06fh
  lcall lcd_data
  mov lcd_buffer,#06ch
  lcall lcd_data
  mov lcd_buffer,#068h
  lcall lcd_data
  mov lcd_buffer,#061h
  lcall lcd_data
  mov lcd_buffer,#020h
  lcall lcd_data
  mov lcd_buffer,#064h
  lcall lcd_data
  mov lcd_buffer,#065h
  lcall lcd_data
  mov lcd_buffer,#020h
  lcall lcd_data
  mov lcd_buffer,#041h
  lcall lcd_data
  mov lcd_buffer,#020h
  lcall lcd_data
  mov lcd_buffer,#061h
  lcall lcd_data
  mov lcd_buffer,#020h
  lcall lcd_data
  mov lcd_buffer,#046h
  lcall lcd_data
  ret

mensagem_3:
;confirme ou
;cancele o voto

  lcall lcd_clear
  mov lcd_buffer,#043h
  lcall lcd_data
  mov lcd_buffer,#06fh
  lcall lcd_data
  mov lcd_buffer,#06eh
  lcall lcd_data
  mov lcd_buffer,#066h
  lcall lcd_data
  mov lcd_buffer,#069h
  lcall lcd_data
  mov lcd_buffer,#072h
  lcall lcd_data
  mov lcd_buffer,#06dh
  lcall lcd_data
  mov lcd_buffer,#065h
  lcall lcd_data
  mov lcd_buffer,#020h
  lcall lcd_data
  mov lcd_buffer,#06fh
  lcall lcd_data
  mov lcd_buffer,#075h
  lcall lcd_data
  mov lcd_buffer,#020h
  lcall lcd_data
  mov lcd_buffer,#020h
  lcall lcd_data
  mov lcd_buffer,#020h
  lcall lcd_data
  mov lcd_buffer,#020h
  lcall lcd_data
  mov lcd_buffer,#020h
  lcall lcd_data
  mov lcd_buffer,#063h
  lcall lcd_data
  mov lcd_buffer,#061h
  lcall lcd_data
  mov lcd_buffer,#06eh
  lcall lcd_data
  mov lcd_buffer,#063h
  lcall lcd_data
  mov lcd_buffer,#065h
  lcall lcd_data
  mov lcd_buffer,#06ch
  lcall lcd_data
  mov lcd_buffer,#065h
  lcall lcd_data
  mov lcd_buffer,#020h
  lcall lcd_data
  mov lcd_buffer,#06fh
  lcall lcd_data
  mov lcd_buffer,#020h
  lcall lcd_data
  mov lcd_buffer,#076h
  lcall lcd_data
  mov lcd_buffer,#06fh
  lcall lcd_data
  mov lcd_buffer,#074h
  lcall lcd_data
  mov lcd_buffer,#06fh
  lcall lcd_data
  ret

mensagem_escolhido:
;x foi escolhido
;Y votos
  lcall lcd_clear
  mov lcd_buffer,#027h
  lcall lcd_data
  mov lcd_buffer,escolhido
  lcall lcd_data
  mov lcd_buffer,#027h
  lcall lcd_data
  mov lcd_buffer,#020h
  lcall lcd_data
  mov lcd_buffer,#076h
  lcall lcd_data
  mov lcd_buffer,#065h
  lcall lcd_data
  mov lcd_buffer,#06eh
  lcall lcd_data
  mov lcd_buffer,#063h
  lcall lcd_data
  mov lcd_buffer,#065h
  lcall lcd_data
  mov lcd_buffer,#075h
  lcall lcd_data
  mov lcd_buffer,#021h
  lcall lcd_data
  mov lcd_pos,#10h
  mov lcd_buffer,#076h
  lcall lcd_data
  mov lcd_buffer,#06fh
  lcall lcd_data
  mov lcd_buffer,#074h
  lcall lcd_data
  mov lcd_buffer,#06fh
  lcall lcd_data
  mov lcd_buffer,#073h
  lcall lcd_data
  mov lcd_buffer,#03ah
  lcall lcd_data
  mov lcd_buffer,#020h
  lcall lcd_data
  mov lcd_buffer,votos
  lcall lcd_data
  ret

end
