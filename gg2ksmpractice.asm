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
	;!lag_state      = $4C ;set to 1 if in a lag frame?
	!stage_state     = $84
	!rng             = $8C
	!current_screen  = $98 ; seems to be something slightly different in truth, like "screen to be loaded" or something like that
	;!current_level  = $F4 ; ?
	!timer           = $AE

	!ryo = $0474
	!helmet_state = $0478
	!helmet_count = $0479
	!armor_state  = $047A
	!armor_count  = $047B
	!onigiri_state = $047C
	!weapon_state = $0460

	!lives = $0498

	!final_boss_health = $05C6

	!status_bar = $1880

	!impact_health = $1B48

	!kill_counter = $1BA4

	!hp = $0446

	!impact_autoscroller_health = $0486

	!container = $04B4

	!impact_in_overworld_flag = $1ACC

	!screen_brightness = $1FA0
}

{
	; new ram
	!lag_counter = $7E5ED0

	!temp_lag_counter = $7E5ED2
	!timer_current_room_minutes = $7E5ED4
	!timer_current_room_seconds = $7E5ED6
	!timer_current_room_frames = $7E5ED8

	!previous_screen = $7E5EDA
}

{ ;game state defines
	!gs_debug = $0007
	!gs_map   = $0008
	!gs_stage = $0009
}

{ ;hijacks / patches
org $80810C : jsr update_hud

org $83C0D7 : nop #2 ; Allowing the player to reenter past stages

org $80812A : jsl infinite_resources ; Ryo and Impact Bomb Hook

org $808580 : jml every_overworld_frame

org $80874A : jsl every_gameplay_frame

org $808B63 : nop #2 ; disable timer death

org $80C3BA : nop #2 ;ignore "can exit levels" check
org $80C3DF : stz !impact_in_overworld_flag : bra exit_level ; clear impact-on-map flag and skip other checks
org $80C402 : exit_level: ;always exit if start + select was pressed

org $80C5DC : jsr every_frame_non_lag : nop #2 ;start press check

org $828D4C : lda #$0999 ;add ryo to boss fights

org $828D55 : jsl impact_bombs : nop ; add 2 bombs to boss fights

org $83ACB6 : nop #2 ; stop lives from decreasing

org $83C0DC : jsl on_level_entry : nop ; runs as soon as you select a level from the overworld

org $83F0A9 : nop #3	; don't print the flashing text for player 2

org $83F4DB : bra $7B : nop ; skip updating ryo and lives hud graphics every frame, reduces lag

org $83FA49 : bra $3B ; Start at the start (disables checkpoints)

org $8AC645 : jsl print_kill_count : nop #2 ; on-enemy-kill hook

org $BAFA65 : jsl mark_stages_completed
}

org $80FD40 ;bank 80 custom code location

{ ;custom code
every_frame_non_lag:

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
	bit #!y
	beq .y_not_pressed
		
;Y pressed. toggle hp
	lda !container : sta !hp

.y_not_pressed		

	lda !buttons_pressed
	bit #!down
	beq .down_not_pressed
		
		;down pressed. toggle weapon
	lda !weapon_state : inc : and #$0003 : sta !weapon_state

.down_not_pressed
	lda !buttons_pressed
	bit #!up
	beq .up_not_pressed

		;up pressed. toggle health containers
		lda !container : lsr : inc
		cmp #$0006
		bcc +
		lda #$0003
+		asl : sta !container
		sta !hp				; set health to new container value

.up_not_pressed:
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

	;normal start press, pause the game
	inc ;clear zero flag so game pauses
	rts

.level_select:
	lda #$0007 : sta !game_state
	pla ;adjust stack so rtl goes to the right place
	rtl

.armor_state:
	db 0, 0
	db 1, 1
	db 2, 3
	db 3, 5

.weapon_state
	db 0, 0
	db 1, 1
	db 2, 2
}

{
every_gameplay_frame:
; timer main
+	lda !stage_state
	; don't run if outside of gameplay
	cmp #$0007
	bcs .done

	cmp #$0003
	bcc .done

.run_timer:
	; if we're on the final boss and its health has reached 0, print the timer on screen
	lda !current_screen : cmp #$0029 : bne +
	lda !final_boss_health : bne +

	jsl print_timer

	bra .done

	; if we've changed rooms, print the timer on screen to show progress
+	lda !current_screen : cmp !previous_screen : beq .update_timer

	jsl print_timer

	bra .done

.update_timer
	;increment frame count by 1, rollover at 60
	;the frame counter is incremented by 1, plus the amount of lag frames that have occurred in the previous period
	sed 

	lda !timer_current_room_frames : clc : adc #$0001 : adc !temp_lag_counter : sta !timer_current_room_frames
	cmp #$0060 : bcc .done
	lda #$0000 : sta !timer_current_room_frames

	lda !timer_current_room_seconds : clc : adc #$0001 : sta !timer_current_room_seconds
	cmp #$0060 : bcc .done
	lda #$0000 : sta !timer_current_room_seconds

	lda !timer_current_room_minutes : clc : adc #$0001 : sta !timer_current_room_minutes
	cmp #$0010 : bcc .done

	; minutes count is 10, stop updating the timer
	lda #$0009 : sta !timer_current_room_minutes
	lda #$0059
	sta !timer_current_room_seconds : sta !timer_current_room_frames

.done
	cld 

	lda !current_screen : sta !previous_screen
	lda #$0000 : sta !temp_lag_counter

	; restore hijacked instruction
	jsl $80C374

	rtl 

}

{
every_overworld_frame:
	jsl print_timer

	jsl clear_hud_stats

	; restore hijacked instruction
	jml $83BE16
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

	cmp #$0006
	bne .return

.inc_counter:
	sed

	lda !lag_counter
	clc
	adc #$0001
	sta !lag_counter

	; this is used by the room timer to determine how many lag frames have just occurred
	lda !temp_lag_counter
	clc
	adc #$0001
	sta !temp_lag_counter

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
print_kill_count:
	; restore hijacked instruction 1
	inc !kill_counter

	; print kill counter
	lda !kill_counter
	and #$0007

	ora #$3760
	sta $18E6

	clc : adc #$0010
	sta $1926

	; restore hijacked instruction 2
	lda !kill_counter
	rtl
}

{
clear_lag_counter:
	lda #$0000
	sta !lag_counter
	lda #$0008
	rts
}

{
on_level_entry:
.clear_timer_and_lag:
	jsl $80838A 	; restore hijacked instruction

	lda #$0000 : sta !timer_current_room_minutes : sta !timer_current_room_seconds : sta !timer_current_room_frames
	sta !lag_counter

.clear_hud:
	lda #$3760 : sta $18F8 : sta $18FA : sta $18FC : sta $18E6 : sta $18EA : sta $18EC : sta $18EE : sta $18F0 : sta $18F2
	lda #$3770 : sta $1938 : sta $193A : sta $193C : sta $1926 : sta $192A : sta $192C : sta $192E : sta $1930 : sta $1932

	rtl
}

{
mark_stages_completed:
	sta $700202 ; restore hijacked instruction
	; fill "levels completed" bitfield
	lda #$FFFF
	sta $700236
	sta $700238
	sta $70023A
	sta $70023C
}

{

impact_bombs:
	sta $057C
	lda #$0002
	sta $D4

	rtl

}

{
infinite_resources:
	lda #$9999
	sta $7e0474 ; ryo
	; sta $0000D4 ; 99 impact bombs (removed)

	jml $8093af

	rtl
}

warnpc $80FFAD

org $8CF450
{
print_timer:
	lda !timer_current_room_minutes
	ora #$3760
	sta $18EA

	clc : adc #$0010
	sta $192A


	lda !timer_current_room_seconds
	lsr #4
	ora #$3760
	sta $18EC

	clc : adc #$0010
	sta $192C


	lda !timer_current_room_seconds
	and #$000F
	ora #$3760
	sta $18EE

	clc : adc #$0010
	sta $192E


	lda !timer_current_room_frames
	lsr #4
	ora #$3760
	sta $18F0

	clc : adc #$0010
	sta $1930


	lda !timer_current_room_frames
	and #$000F
	ora #$3760
	sta $18F2

	clc : adc #$0010
	sta $1932

	rtl 
}

{
; without this, the hud would display garbage where ryo and lives are located (due to those things not being updated every frame anymore)
clear_hud_stats:
    sep #$20
    lda #$00 : sta $1888 : sta $188A : sta $188C : sta $188E : sta $18C8 : sta $18CA : sta $18CC : sta $18CE
    sta $190C : sta $190E : sta $194C : sta $194E
    rep #$20

    rtl
    
    org $83F34A : lda #$00 ;remove ryo symbol
    org $83F34F : lda #$00 ;remove ryo symbol

}
