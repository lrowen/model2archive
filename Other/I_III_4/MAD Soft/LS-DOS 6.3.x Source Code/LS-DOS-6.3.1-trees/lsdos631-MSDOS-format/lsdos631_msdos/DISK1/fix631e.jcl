. FIX631E/JCL - 04/30/90 - Corrects release of banks > 7 in SPOOL
. Apply via, DO FIX631E (D=d) where "d" is drive to patch
//if -d
//. Must enter drive to patch!
//quit
//end
PATCH SYS8/SYS.SYSTEM6:#D# SPOOL1/FIX:3
PATCH BOOT/SYS.SYSTEM6:#D# (D02,1F=46:F02,1F=45)
//exit
