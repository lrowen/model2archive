Tandy XENIX 3.x 6 Mhz (short) 68000 CPU Upgrade Kit.

When Tandy released XENIX 3.x a "68000 DMA BURST Mode" feature was added that allowed the Z80 to grab and hold the 68000 bus (apart from refresh cycles) and do DMA directly to/from the 68000 memory to/from Z80 I/O ports, or to/from Z80 memory.

The 8Mhz 68000 CPU card in the 6000 came with this feature but the 6Mhz (short) 68000 CPU card in the Model 16B required a upgraded set of PAL's, one capacitor and few simple modifications detailed in TB 12/16B:44 to add it. Without this upgrade unmodified XENIX 3.x would display the message "Bughlt NewPal - Hardware Change Required" and refuse to run.

In addition to the new feature Tandy also used TB 12/16B:44 as an opportunity to fix some memory related issues and replace U48 with what was referred to internally as the "corrected PAL". Both of these issues were corrected at the factory on the 8mhz CPU board. 

Unfortunately 30+ years later so few of the upgraded 6Mhz CPU cards seem to exist they are regarded as rare and seeing as how the Model 16B was the best selling UNIX workstation of 1984 I think we should fix that.

This archive contains everything you need to perform the upgrade aside from components. 

Components needed:

16R4  PAL (U48) - Program this with U48.JED (I used a TI TIBPAL164R-25CN)
16R6A PAL (U36) - Program this with U36.JED (I used a MMI PAL16R6ACN)
330pf Capacitor - I used Digikey Part# 399-C322C331J5G5TA-ND
~1.5" of 22-24G Stranded Wire 
~13" of "Standard" Bodge Wire

Read both pages of the included 12/16B:44 technical bulletin and familiarize yourself with the changes it details against your 6mhz short CPU board. You'll want to make sure that the BERR and WAIT modifications were not already done to your board in TB 12/16B:41 and if they were simply skip those steps. 

I've included annotated images of the modification to my board you can reference but the modifications are simple and you should have no trouble.

IMHO XENIX 3.x (UNIX System III) is such an improvement over TRS-XENIX 1.x (Seventh Edition Unix) if you actually use your system you'll really appreciate the changes and use it more. XENIX 3.3 with its virtual console support would have been a real game changer had Tandy officially released it.

Enjoy!




