Tandy XENIX 3.x 6 Mhz long 68000 CPU Upgrade

Tandy never officially supported adding the DMA BURST Mode feature to the 6 Mhz long 68000 CPU board. In TB 12/16B:44 they even go as far as saying that it cannot be added which is unfortunate because today the long board seems to be the most prolific of all the 68000 CPU boards.

Lucky for long board owners it seems that this was not the case. There are usenet posts from Tandy engineers saying it possible but Tandy wanted the long boards out of circulation, posts from users who ran the modified boards in their systems and even a post that Bob Snapps company Snapp-ware would do the modification. So unofficially the modification was done but nobody ever seemed to have documented what was needed or how to do it....

Well, earlier this year I came into possession of a long board from a former Tandy engineer that has the burst mode modification. Initially I thought it was just another 68000 long board but when I looked at it more closely pin 5 of U34 was lifted from the socket and jumpered to a 74 series chip on the other side of the board. This is the same sort of modification you'll see on all 8 Mhz boards and upgraded 6 Mhz boards. I put the CPU board into a machine and to my surprise XENIX 3 booted without issue!

So to try and resurrect this I dumped all of the PALs, documented every cut/jump and successfully applied the modification to one of my stock long boards. The modification is very simple requiring no cuts and is easily reversed.

Before I go into all the gory details this is how you add burst mode support to the 6 Mhz long board:

Write U34-PAL16R6-46D4.JED to a 16R6A PAL.
Bend pins 11 and 5 up so as not to come in contact with the socket when installed.
Remove the old PAL in the U34 position.
Install the new PAL into U34 (Checksum 46D4).
Jump pin 11 to pin 10.
Jump pin 5 to pin 2 of U37.

Thats it.

It should be noted that when the 6 Mhz short board is upgraded the BERR and WAIT modifications are done in addition to replacing the PAL at U48 with new code. I don't know if the BERR or WAIT modifications could or should be applied to the long board nor do I know if the issues that exist with the code in U48 on the short board are an issue with the long board (U49 and U57 on the long board are the equivalent of U48 on the short board). 

I do know that after the modification all of the 68000 diagnostics pass, XENIX 3.x runs without issue and the modified board that I have is identical in every way to the stock board I modified aside from the previously mentioned U34 changes. Also the U34 "burst mode" code used here is identical to U36 on the 8 Mhz and upgraded 6 Mhz boards. Overall the modification is very easy to do and undo without any permanent changes to your board.

There is some anecdotal information that while the long board with the modification will work under XENIX 3.x it is not as reliable as the 8 Mhz or upgraded 6 Mhz short board. This seems to vary from board to board and while both the boards I have seem to work fine YMMV. Since this does not occur with every board if it is uncovered it would be nice to identify what the issue is and potentially fix it.

Archive contents:

Modified 6mhz Long Component Side.jpg          - Picture of Modified 6mhz board.
Modified 6mhz Long Solder Side.jpg             - Picture of Modified 6mhz board.
Stock 6mhz Long Component Side Unmodified.jpg  - Picture of Stock 6mhz board.
Stock 6mhz Long Solder Side Unmodified.jpg     - Picture of Stock 6mhz board.
Stock 6mhz After Modifications.jpg             - Annotated picture of Stock 6mhz board after modifications.
Stock 6mhz Long (Board 3) Component Side.jpg   - Picture of Stock Board "B".
Stock 6mhz Long (Board 3) Solder Side.jpg      - Picture of Stock Board "B".
XENIX 3.2 Before Modifications.jpg             - Screen shot of XENIX 3.2 (stock board) before modifications.
XENIX 3.2 After Modifications.jpg              - Screen shot of XENIX 3.2 (stock board) after modifications.
U12-PAL16R6-7C60.jed                           - U12 PAL code from modified board.
U34-PAL16R6-46D4.jed                           - U34 PAL code from modified board.
U49-PAL16R8-88AC.jed                           - U49 PAL code from modified board.
U57-PAL12L6-22CA.jed                           - U57 PAL code from modified board.

Comparison of the modified board and 2 variations of a stock 68000 long board.

In addition to the modified board I've identified 2 variations of the 68000 board and this is an attempt to document the cuts, jumps and jumper settings on all 3 boards. I have physical access to boards 1 and 2 listed below but only have pictures of board 3. I believe that board 3 is the latest revision of the long board and would eventually like to dump the PALs from it. 

Board 1 - Modified board.
Board 2 - Stock board "A" (My stock board before modification).
Board 3 - Stock board "B".

All 3 boards have the following information on the board.

Component side:

LEI LEM-1
        21 82
		
Solder side:

TANDY CORP.
(c) 1981
MADE IN U.S.A.

"8709235 PP 4" on far right of board.

Board 1 has a clear sticker with "038210" in white on far left.
Board 2 has a clear sticker with "032382" in white on far left.
Board 3 has a clear sticker with "050958" in white on far left.

All 3 boards have the same jumpers set: 

E3-E10  
E16-E19 
E29-E30 
E33-E34 

PALs:

Board 1 U12 - PAL16R6 checksum 7C60, Hand written "12" on sticker.
Board 2 U12 - PAL16R6 checksum 7C60, Hand written "12" on sticker.
Board 3 U12 - <Needs Dumped>, Clear sticker with "120BF6" in white.

Board 1 U34 - PAL16R6 checksum 46D4, No label remains. 
Board 2 U34 - PAL16R6 checksum 4C33, Hand written "34" on sticker. 
Board 3 U34 - <Needs Dumped>, Clear sticker with "34063F" in white.

Board 1 U49 - PAL16R8 checksum 88AC, Hand written "49" on sticker.
Board 2 U49 - PAL16R8 checksum 88AC, Hand written "49" on sticker.
Board 3 U49 - <Needs Dumped>, Clear sticker with "4910AC" in white.

Board 1 U57 - PAL12L6 checksum 22CA, Hand written "57" on sticker.
Board 2 U57 - PAL12L6 checksum 22CA, No label remains.
Board 3 U57 - <Needs Dumped>, Clear sticker with "570518" in white.

I'm 99% sure the stickers on U12, U48 and U57 of Board 3 are in the format of <Position><Checksum> and could contain newer PAL code.

U34 PAL jumpers:

Board 1 - U34 pin 11 lifted and jumpered to pin 10. 
          U34 pin 5 lifted and jumpered to pin 2 of U37.
Board 2 - U34 pin 11 lifted and jumpered to top of C28.
Board 3 - U34 pin 11 lifted and jumpered to pin 10.

All 3 boards have the following cuts:

Edge card pin trace 48 cut (pin directly below the J on the J0 silk screen).
Trace between feed-thru at the top and slightly covered by U12 and feed-thru between R8 and C25 cut.

All 3 boards have the following jump:

U49 pin 2 jumpered to pin 5 on solder side.

Boards 1 and 2 have the following jumps:

Feed-thru at the top and slightly above U12 jumpered to feed-thru between and just below pins 13-14 on U58 on the solder side.

Jumper from edge card pin 48 of component side, goes through empty feed-thru above edge card pin 52 to solder side of board and connects to the feed-thru between R8 and C25.

Board 3 has the following jumps:

Jumper from feed-thru between and just below pins 15 and 16 on U58 on component side, goes through empty feed-thru just below E25 to solder side of board and connects to pin 2 of RP9.

Jumper from edge card pin 48 to feed-thru just above R8 on component side.

This appears to just be a refinement of the above jumps on boards 1 and 2.

I believe all cuts and jumps were done at the factory as they are not mentioned in any TB.