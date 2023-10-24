lorom

{ ;inputs
	!l      = $0020	
	!r      = $0010
    !x      = $0040
	!a      = $0080
	!y      = $4000
	!b      = $8000
	!up     = $0800
	!down   = $0400
	!left   = $0200
	!right  = $0100
	!start  = $1000
	!select = $2000
}

{ ;ram
    !buttons_held    = $36
    !buttons_pressed = $38
    !game_state      = $42
    !frame_counter   = $4A
	; !lag_state       = $4C ;set to 1 if in a lag frame?
    !stage_state     = $84
    !rng             = $8C
	!timer           = $AE

    !ryo = $0474
    !helmet_state = $0478
    !helmet_count = $0479
    !armor_state  = $047A
    !armor_count  = $047B
	!onigiri_state = $047C
	!weapon_state = $0460

    !lives = $0498

	!status_bar = $1880

    !impact_health = $1B48

    !maneki_neko_counter = $1BA4

	!hp = $0446

	!container = $04B4

	!lag_counter = $7ED0F0
}

{ ;game state defines
	!gs_debug = $0007
	!gs_map   = $0008
	!gs_stage = $0009
}

{ ;hijacks / patches
org $80C5DC : jsr add_items_level_select : nop #2 ;start press check

org $80810C : jsr update_hud

org $80E953 : jsr clear_lag_counter

org $828D4C : lda #$0999 ;add ryo to boss fights

org $83F0A9 : nop #3	; don't print the flashing text for player 2

org $83C0DC : jsl clear_hud : nop ; runs as soon as you select a level from the overworld

org $83C0D7 : nop #2 ; Allowing the player to reenter past stages

org $83FA49 : bra $3B ; Start at the start (disables checkpoints)

org $80c3f9 : nop #2 ; Castle "Start + Select" Exits

org $80812a : jsl infinite_resources ; Ryo and Impact Bomb Hook
}

org $80FD40 ;bank 80 custom code location

{ ;custom code
add_items_level_select:
	lda !buttons_held ;A = buttons held
	bit #!select      ;A & $2000
	beq .select_not_pressed

	;select is being held. check for button presses
	lda !buttons_pressed
	bit #!r
	beq .r_not_pressed

	;r pressed. toggle armor
	lda !armor_state : inc : and #$0003 : asl : tax ;X: next armor state
	lda.l .armor_state,X : sta !armor_state

	; fall through to continue to check for button presses

.r_not_pressed:
    ;check for l press
    lda !buttons_pressed
    bit #!l
    beq .l_not_pressed

    ;l pressed. toggle helmet
        lda !helmet_state : inc : and #$0003 : asl : tax ;X: next helmet state
		lda.l .armor_state,X : sta !helmet_state
        ; fall through to continue to check for button presses

.l_not_pressed:

;check for x press
    lda !buttons_pressed
    bit #!x
    beq .x_not_pressed
        
	    ;X pressed. toggle onigiri
        lda !onigiri_state : inc : and #$0003 : sta !onigiri_state

.x_not_pressed

;check for y press (not working yet)
    lda !buttons_pressed
    bit #!y;    beq .y_not_pressed
	beq .y_not_pressed
        
   ;Y pressed. toggle hp
       lda !container : sta !hp

.y_not_pressed		

	lda !buttons_pressed
    bit #!down
    beq .right_not_pressed
        
	    ;down pressed. toggle weapon
       lda !weapon_state : inc : and #$0003 : sta !weapon_state

.right_not_pressed

	;add more checks and button combos here

.select_not_pressed: ;check for start press
	lda !buttons_pressed
	bit #!start
    bne .start_pressed

	rts ;start or select not pressed. resume as normal

.start_pressed:
	lda !buttons_held
    bit #!x
	bne .level_select

    bit #!a
	bne .exit_impact

	;start pressed, pause the game
	inc ;clear zero flag so game pauses
    rts

.level_select:
    lda #$0007 : sta !game_state
    pla ;adjust stack so rtl goes to the right place
    rtl

.exit_impact:
	lda #$0000 : sta !impact_health
	lda #$0007 : sta !stage_state
	pla
	rtl

.armor_state:
    db 0, 0
	db 1, 1
	db 2, 3
	db 3, 5

;.helmet_state
;	db 0, 0
;	db 1, 1
;	db 2, 3
;	db 3, 5

.weapon_state
	db 0, 0
	db 1, 1
	db 2, 2

}
{
update_hud:
	jsr $8240

	lda !game_state
	cmp #$0009
	bne .return

	lda $1FA0
	cmp #$000F
	bne .return

	lda !stage_state
	cmp #$0003
	beq .inc_counter

	lda !stage_state
	cmp #$0006
	bne .return

.inc_counter:
	sed
	lda !lag_counter
	clc
	adc #$0001
	sta !lag_counter
	cld

	; print the lag counter on screen
	lda !lag_counter+1
	and #$000F			; work on the hundreds digit

	clc 

	ora #$3760
	sta $18F8			; this is inside the hud buffer from vram in wram

	adc #$0010
	sta $1938

	lda !lag_counter	; work on the tens digit
	and #$00F0
	lsr #4


	ora #$3760
	sta $18fA

	adc #$0010
	sta $193A

	lda !lag_counter
	and #$000F

	ora #$3760
	sta $18FC

	adc #$0010
	sta $193C


.return:
	rts
}

{
clear_lag_counter:
	lda #$0000
	sta !lag_counter
	lda #$0008
	rts
}

{
clear_hud:
	jsl $80838A 	; restore hijacked instruction

	lda #$3760
	sta $18F8
	sta $18FA
	sta $18FC

	lda #$3770
	sta $1938
	sta $193A
	sta $193C

	rtl
}

{
infinite_resources:
	lda #$9999
	sta $7e0474 ; ryo
	sta $0000D4 ; impact bombs

	jml $8093af

	rtl

	org $83ACB6 : nop #2 ; stop lives from decreasing
	org $808B63 : nop #2 ; disable timer death
	;org $808B65 : nop #3 ; disable timer beeps

}