. FIX631G/JCL - 08/27/90 - Corrects MEMGORY command display when the 
. information uses more than one screen.
. Apply via, DO FIX631G (D=d) where "d" is drive to patch
//if -d
//. Must enter drive to patch!
//quit
//end
PATCH SYS6/SYS.SYSTEM6:#D# USING MEMORY1/FIX:3
PATCH BOOT/SYS.SYSTEM6:#D# (D02,1F=48:F02,1F=47)
//exit
