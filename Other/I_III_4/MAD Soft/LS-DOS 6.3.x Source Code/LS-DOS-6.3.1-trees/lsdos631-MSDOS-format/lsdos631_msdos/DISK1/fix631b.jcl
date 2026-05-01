. FIX631B/JCL - 04/03/90 - Add missing code to SETKI
. Apply via, DO FIX631B (D=d) where "d" is drive to patch
//if -d
//. Must enter drive to patch!
//quit
//end
patch boot/sys.system6:#d# (d02,1f=43:f02,1f=42)
patch sys8/sys.system6:#d# using setki1/fix:3
//exit
