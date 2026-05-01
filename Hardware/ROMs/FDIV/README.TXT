Frank Durda's Enhanced Model II/16/6000 Boot ROM

Thanks to dlightman for providing this package.

Frank added support for the Model 2000 keyboard and Hitachi HD64180 along with a host of other fixes and optimizations. 

The ROM (FDIV_89.bin) has the checksum of DF85 in a reader and AD85 in MEMII. I've ran it in a 16A, 16B, 6000 and trs80gp for about 6 months without any issues. It feels like the initialization and boot is faster but I haven't validated that against C9AC. 

When the XENIX 3.3 upgrade was released I started using the 2000 keyboard to take advantage of the "new" virtual console support. The downside is you can't type anything until XENIX boots and z80ctl loads. This ROM restores some of that and recognizes the break key so you can boot from floppy but whatever you boot also needs to know how to deal with the scan code differences. 

BOOTROM.TAR contains the source code and binaries for several ROM's that can be built using ALDS. FDIV_89.bin was built from the code inside of the bootrom\new directory dated 04/1989. 