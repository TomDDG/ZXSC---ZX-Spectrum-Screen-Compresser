;;
;; example here is a window 0x,0y to 12x,12y
  ld hl,data
  ld de,22528 ; fixed at attribute 0x,0y
  call _uclzf020
  ret
;;
;; static window decompression 92bytes long
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
  cp 12 ; xstart+xsize
  ret nz
  ld a,e
  add a,20 ; 32-xsize
  ld e,a
  ret nc
  inc d
  ret
data:
;; compressed data here
