. FIX631C/JCL - 04/18/90 - Minor correction to DIR
. Apply via, DO FIX631C (D=d) where "d" is drive to patch
//if -d
//. Must enter drive to patch!
//quit
//end
patch boot/sys.system6:#d# (d02,1f=44:f02,1f=43)
patch sys6/sys.system6:#d# dir1/fix:3
//exit
