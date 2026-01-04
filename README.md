# ZXSC---ZX-Spectrum-Screen-Compresser

As part of developing some of my games on the ZX Spectrum I had a requirement for a screen compressor to not only store title, loading or end game screens but also for cutouts of the screen for story boards or similar. I therefore did some research to find a suitable compression routine, one that's de-compressor could easily be run on a ZX Spectrum with its 3.5MHz Z80 processor and 48k of memory. My main requirements were:

- Gave a good compression ratio for ZX Spectrum Screens
- Works in limited memory i.e. 48k ZX Spectrum
- Fast (on real hardware) & compact de-compressor that can be coded easily in z80
- Allows for compression of cutouts/windows of the screen not just full screens
- De-compression is visually pleasing i.e. doesn't show garbage on screen

After much experimenting and research I ended up choosing LZF compression originally by Marc Lehmann, a part of the popular LZ77 algorithm family. Although it doesn't give the best compression, it is very fast even on a Spectrum, needs no working memory, utilising the already de-compressed data as a dictionary and has an inherent 8kb (13bit) offset which fits nicely as a Spectrum screen is 6912bytes long. For more info see Wikipedia (https://en.wikibooks.org/wiki/Data_Compression/Dictionary_compression#LZF)

Below are details on the algorithm including how it compresses the data, how the de-compression works, modifications to the standard I've made and how I built my compression code including the parser chosen to achieve maximum compression.

## Compression Method

Each LZF compressed byte can be one of the following 3 items:

- `000LLLLL` - copy next L+1 literal bytes from the compression storage
- `LLLPPPPP PPPPPPPP` - copy L+2 from P memory position or P+1 offset
- `111PPPPP LLLLLLLL PPPPPPPP` - copy L+9 from P memory position or P+1 offset

The LZF compressor scans from the current byte to see if there is a match in the already processed memory, defined as the dictionary, of that byte and the bytes following it. It then determines:

- If the "string" of bytes it finds is more than 3 in length it stores a compressed version which will be either 2 or 3 from the list above depending on length. 3-8 use 2, 9+ uses 3
- If not it stores just the byte (literal) and a control byte if required as defined by 1 above
Initial bytes are always a control (000LLLLL) followed by a literal or literals, otherwise there would be nothing in the dictionary! Anyway a couple of simple examples:

If we have 16 zeros in a row the compressor would store this in 5 bytes (plus an end marker). These bytes are as follows:

- `0x00` which is a control byte -> copy one literal
- `0x00` which is the literal to copy 0
- `0xe0` which is `%11100000` which means grab the next byte to get the full length & 5 high bits of the offset
- `0x06` which when added to the previous byte gives a length of 15. Basically 7+2=9+6=15
- `0x00` which combined with the previous 5 high bits gives an offset of 1 (0+1) so basically copy 15 0s from 1 position back
- `0xff` end marker

If we have "123456" then the compressor won't actually compress at all, in fact it would result in a file longer than the original at 8 bytes. This is because it won't find a match in the dictionary so it will just store the literals 123456 with a control byte (`%00000101`) in front and an end marker afterwards. If however we have "123456123456" we will start to see how the compression works. Starting with the same initial 7bytes (control byte followed by the string "123456") we would then get:

- `0x80` (`%10000000`) - copy 6 bytes (4+2) from...
- `0x05` (`%00000101`) - offset 6 (5+1) or go 6 back and copy 6 bytes
- `0xff` - again an end marker
