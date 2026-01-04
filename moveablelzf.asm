  ld hl,data
  ld de,xxx ; xxx can be any attribute, be careful with screen edges
  call _uclzf
  ret
;;
;; moveable window decompression 151bytes long
_uclzf:
  ld a,e
  and 31
  ld (_uclzf040+1),a ; loaded into code
  add a,(hl) ; get width of window from compression data
  and 31
  ld ixl,a ; store in ixl for later
  ld a,32
  sub (hl)
  ld ixh,a
  inc hl
  ld a,e
  and 224
  add a,d
  sub 88
  rlca
  rlca
  rlca
  ld (_uclzf050+1),a
  jr _uclzf020
_uclzf010:
  call _uclzf100
  inc hl
  djnz _uclzf010
_uclzf020:
  ld a,(hl)
  inc hl
  ld b,a
  inc b
  ret z
  cp 32
  jr c,_uclzf010
  ld c,a
  and 224
  rlca
  rlca
  rlca
  cp 7
  jr nz,_uclzf030
  add a,(hl)
  inc hl
_uclzf030:
  add a,2
  ld b,a
  push hl
  ld a,c
  and 31
  add a,64
  ld l,(hl)
  ld h,a
_uclzf040:
  ld a,0 ; loaded from top
  add a,l
  ld l,a
_uclzf050:
  ld a,0
  or a
  jr z,_uclzf080
  ld c,a
_uclzf060:
  ld a,l
  add a,32
  ld l,a
  jr nc,_uclzf070
  inc h
  ld a,h
  cp 88
  jr nc,_uclzf070
  add a,7
  ld h,a
_uclzf070:
  dec c
  jr nz,_uclzf060
_uclzf080:
  call _uclzf100
  ex de,hl
  call _uclzf110
  ex de,hl
  djnz _uclzf080
  pop hl
  inc hl
  jr _uclzf020
_uclzf100:
  ld a,(hl)
  ld (de),a
_uclzf110:
  ld a,d
  cp 88
  jr c,_uclzf120
  rlca
  rlca
  rlca
  xor 130
  ld d,a
  ret
_uclzf120:
  inc a
  ld d,a
  and 7
  ret nz
  xor d
  rra
  rra
  rra
  add a,79
  ld d,a
  inc de
  ld a,e
  and 31
  cp ixl
  ret nz
  ld a,e
  add a,ixh
  ld e,a
  ret nc
  inc d
  ret
data:
;; compressed data here
