# ZXSC---ZX-Spectrum-Screen-Compresser

As part of developing some of my games on the ZX Spectrum I had a requirement for a screen compressor to not only store title, loading or end game screens but also for cutouts of the screen for story boards or similar. I therefore did some research to find a suitable compression routine, one that's de-compressor could easily be run on a ZX Spectrum with its 3.5MHz Z80 processor and 48k of memory. My main requirements were:

- Gave a good compression ratio for ZX Spectrum Screens
- Works in limited memory i.e. 48k ZX Spectrum
- Fast (on real hardware) & compact de-compressor that can be coded easily in z80
- Allows for compression of cutouts/windows of the screen not just full screens
- De-compression is visually pleasing i.e. doesn't show garbage on screen

After much experimenting and research I ended up choosing LZF compression originally by Marc Lehmann, a part of the popular LZ77 algorithm family. Although it doesn't give the best compression, it is very fast even on a Spectrum, needs no working memory, utilising the already de-compressed data as a dictionary and has an inherent 8kB (13bit) offset which fits nicely as a Spectrum screen is 6912bytes long. For more info see [Wikipedia](https://en.wikibooks.org/wiki/Data_Compression/Dictionary_compression#LZF)

Below are details on the algorithm including how it compresses the data, how the de-compression works, modifications to the standard I've made and how I built my compression code including the parser chosen to achieve maximum compression.

## Compression Method

Each LZF compressed byte can be one of the following 3 items:

- `000LLLLL` - copy next L+1 literal bytes from the compression storage
- `LLLPPPPP PPPPPPPP` - copy L+2 from P memory position or P+1 offset
- `111PPPPP LLLLLLLL PPPPPPPP` - copy L+9 from P memory position or P+1 offset

The LZF compressor scans from the current byte to see if there is a match in the already processed memory, defined as the dictionary, of that byte and the bytes following it. It then determines:

- If the "string" of bytes it finds is more than 3 in length it stores a compressed version which will be either 2 or 3 from the list above depending on length. 3-8 use 2, 9+ uses 3
- If not it stores just the byte (literal) and a control byte if required as defined by 1 above
Initial bytes are always a control `000LLLLL` followed by a literal or literals, otherwise there would be nothing in the dictionary! Anyway a couple of simple examples:

If we have 16 zeros in a row the compressor would store this in 5 bytes (plus an end marker). These bytes are as follows:

- `0x00` which is a control byte -> copy one literal
- `0x00` which is the literal to copy 0
- `0xe0` which is `%11100000` which means grab the next byte to get the full length & 5 high bits of the offset
- `0x06` which when added to the previous byte gives a length of 15. Basically 7+2=9+6=15
- `0x00` which combined with the previous 5 high bits gives an offset of 1 (0+1) so basically copy 15 `0`s from 1 position back
- `0xff` end marker

If we have `123456` then the compressor won't actually compress at all, in fact it would result in a file longer than the original at 8 bytes. This is because it won't find a match in the dictionary so it will just store the literals `123456` with a control byte (`%00000101`) in front and an end marker afterwards. If however we have `123456123456` we will start to see how the compression works. Starting with the same initial 7bytes (control byte followed by the string `123456`) we would then get:

- `0x80` (`%10000000`) - copy 6 bytes (4+2) from...
- `0x05` (`%00000101`) - offset 6 (5+1) or go 6 back and copy 6 bytes
- `0xff` - again an end marker

## Decoding Example

Fetch byte X from the compressed file and break into:

- 3bit length L (0-7)
- 5bit (P)position or Multiple if L=0 (0-31)

Then If

- L=0 then copy the next P+1 byte(s) (literal)
- L<7 then short copy of L+2 bytes from prior memory location defined by P
- L=7 then long copy of L+2+next byte from prior memory defined by P

The prior memory location/offset is obtained by combining the 13bits as defined above. In the original LZF algorithm P is an offset which is subtracted from the current memory position (P+1 as zero cannot an offset). This was modified for the screen compression routine as detail next.

# Modifications

For the screen version of the compressor instead of reading the memory in a linear fashion the compressor follows the Spectrum screen layout as follows:

- attribute character square byte
- 8 pixel rows for same character square
- next attribute character square byte etc...

This resulted in much better compression (up to 20% for some screens) plus fulfills the nicer reveal of the screen when decompressing criteria (example of this below). In addition for the screen version the offset is encoded as the actual memory position 0-6913 which is then added to 16384 in the de-compressor. This is in order to get the correct screen position as using an offset would be difficult due to the non-linear way the screen is scanned. Normal version works as an offset as per the original specifications. Finally after rigorous testing:

- The minimum length of a match was taken as 3, <3 matches are stored as literals
- Max length was capped at 256 to make the decompression code cleaner and faster. From testing there are limited times >256 is required. Second byte for length therefore maxes out at 246
- `0xFF` is used as an end marker meaning the max offset or memory position is actually 7936 `%11110 11111111` to avoid issues with lengths >=9.

# Parser Info

Probably one of the most important parts of the compression code outside of the actual algorithm is how the data to be compressed is scanned and/or parsed. Different methods can results in much better or worse compression ratios.

To start with knowledge of the underlying data can have a big impact as proven by the improved ratios obtained by scanning the ZX Spectrum screens in a non-linear fashion. For example a test screen cobra.scr is compressed from 6912 to 2989bytes using standard LZF, whereas the non-linear screen scan version, using the same parser, gives 2348bytes a 21% improvement.

The way the matches are selected or abandoned, known as parsing, can also make a difference, although not as large in this usage case. There is a ton of information on the web on how to obtain "optimal" parsing, especially for LZ77 compressors, although I didn't find a definitive answer to this. I will therefore detail the different methods I tried.

- **Greedy parsing** were for each byte the whole of the dictionary (already processed bytes) is scanned for the longest match x which is then used. The compressor stores this match and then jumps x ahead and checks the next byte. As you can probably guess this is not optimal as there may be a better match in one the x bytes skipped. If we just stored a few literals or a smaller match instead we could then store a much longer match and in theory end up with a better compression ratio. This leads to Lazy parsing.
- **Lazy parsing** were the longest match wasn't always used if a match on one of the potentially skipped bytes had a longer match length. From my testing this sometimes gave a couple of byte improvement but also sometimes a worse one which was interesting. It seems that selecting what seems to be a better match for one instance could actually result in a better match combination being skipped. This led to my third version using a combination of greedy and lazy with a cost calculation to determine if the longer match is in fact better overall.
- **Cost calculator** were for every single byte (no skipping), the best match is determined. This will either be a literal, a 3-8 or a 9+ length match. Then for all bytes a "cost to the end" is calculated using simple Greedy parsing, as detailed above, using the following assignments:
  - Assigned cost of 1 or 2 if no match >3 found. 2 cost if control needed.
  - Assigned 2 cost for 3-8 lengths.
  - Assigned 3 cost for 9+ lengths.

I did experiment with incorporating Lazy matching to the "cost to end" calculation but determined Greedy produced the best results. The next step is to use Lazy matching to determine, for each byte, if the cost to the end is lower for it or for one of the bytes it may potentially skip. If a better cost is found (including the cost of getting to the better one) then it is taken and the compression padded up to that point by either adding one or two literals or by encoding a shorter match.
The Cost Calculator version resulted in the best compression ratios improving upon the simple Greedy parser by around 1%. Although it is slower due to scanning every byte with no skipping, as we are working with modern PCs and small data files this wasn't a problem.

Using the Cobra.scr test screen (6912bytes):

- Simple greedy parser = 2367bytes (65.8% smaller)
- Initial cost calc = 2348bytes (0.8% saving over simple greedy)
- Final improved cost calc = 2337bytes (1.3% saving over simple greedy)
- and as a comparison Linear with same best case parser = 2969bytes

## Compression Code

You can download the compressor for Mac OS X or Windows 32 executables from the release folder. I've also included a test ZX Spectrum tape so you can see the decompression in action. Further below I've listed the z80 decompression assembler source code.

The compression software is a single executable able to compress in both the standard/linear and screen scan versions. The screen version includes full screen, static window or moveable window defined by xstart, ystart, xsize & ysize. It produces the output as assembler defb statements so it can easily be incorporated into your code. You can also opt to include the decompression z80 assembler code in with this.

Small update, added v3c which has fixed an issue when the compressor encounters a file it cannot compress resulting in it not creating the output. I also tidied up the debug output. v3d improved parser, v3e new backwards cost parser which increases compression by a few bytes and is much faster.

Run-time options detailed below:
```
zxsc v3e (c) 2018/20 Tom Dalby
usage: zxsc input [options] <default normal lzf to stdout>
-s compress screen (non-linear screen scan)
-w <XSTART YSTART XSIZE YSIZE> compress static screen cutout
-m <XSTART YSTART XSIZE YSIZE> compress moveable screen cutout
-o <filename> output to file
-a add z80 de-compressor (default, screen or static/moveable cutout)
-d show debugging info & suppress all other output
```

## Decompression z80 code

Four versions of the decompression code are available. They all work slightly differently:
- [Standard LZF](./standardlzf.asm) (49bytes long) - Linear data scan, simplest and therefore smallest code
- [Full Screen LZF](./fullscreenlzf.asm) (80bytes long) - Screen scan version, addition of code to scan the screen as defined, fixed memory location
- [Static Cutout/Window LZF](./staticlzf.asm) (92bytes long) - Windowed version of Screen scan, hard coded checks in the de-compressor to determine if at the edge of the window, fixed memory location
- [Moveable Cutout/Window LZF](./moveablelzf.asm) (151bytes long) - Moveable windowed version of Screen scan, can be any screen location. This makes the de-compression code much longer due to the variable nature of the edge checks required
