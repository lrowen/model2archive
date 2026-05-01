. FIX631A/JCL - 03/08/90 - Cause FORMAT to write all sectors of DIR cyl
. Apply via, DO FIX631A (D=d) where "d" is drive to patch
//if -d
//. Must enter drive to patch!
//quit
//end
patch boot/sys.system6:#d# (d03,1f=42:f02,1f=41)
patch format/cmd.utility:#d# (d03,7f=21:f03,7f=32)
//exit
