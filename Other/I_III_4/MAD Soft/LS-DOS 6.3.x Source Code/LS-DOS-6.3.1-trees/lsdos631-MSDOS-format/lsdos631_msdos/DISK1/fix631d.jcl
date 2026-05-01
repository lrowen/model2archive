. FIX631D/JCL - 04/30/90 - Minor correction to DIR & Memdisk/DCT
. Corrects exit code for DIR; BOOT/SYS & DIR/SYS passwords in Memdisk.
. Apply via, DO FIX631D (D=d) where "d" is drive to patch
//if -d
//. Must enter drive to patch!
//quit
//end
PATCH SYS6/SYS.SYSTEM6:#D# DIR2/FIX
PATCH MEMDISK/DCT.UTILITY:#D# (D04,40=F4 71:F04,40=F6 37)
PATCH MEMDISK/DCT.UTILITY:#D# (D04,60=F4 71:F04,60=F6 37)
PATCH BOOT/SYS.SYSTEM6:#D# (D02,1F=45:F02,1F=44)
//exit
