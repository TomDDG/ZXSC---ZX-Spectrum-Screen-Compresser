  ld hl,data
  ld de,xxx ; edit xxx to where you want to decompress to
  call _ulzf
  ret
;;
;; lzf de-compressor 50bytes long
_ulzf:
  ld b,0
  jr _ulzf020
_ulzf010:
  ldir
_ulzf020:
  ld a,(hl)
  inc hl
  ld c,a
  inc c
  ret z
  cp 32
  jr c,_ulzf010
  push af
  and 224
  rlca
  rlca
  rlca
  add a,2
  cp 9
  jr nz,_ulzf030
  add a,(hl)
  rl b; update to handle up to 264 length
  inc hl
_ulzf030:
  ld c,a
  pop af
  push hl
  push bc
  and 31
  ld b,a
  ld c,(hl)
  ld h,d
  ld l,e
  scf
  sbc hl,bc
  pop bc
  ldir
  pop hl
  inc hl
  jr _ulzf020
data:
;; compressed data here
