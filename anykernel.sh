# AnyKernel3 - OnePlus 11 (salami)
# osm0sis @ xda-developers

properties() { '
kernel.string=LineageOS KSU-Next+SUSFS Kernel for OnePlus 11
do.devicecheck=0
do.modules=1
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=salami
device.name2=OP5916L1
device.name3=CPH2449
device.name4=PHB110
device.name5=OP594DL1
supported.versions=14
' ; }

block=/dev/block/bootdevice/by-name/boot;
is_slot_device=1;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;

. tools/ak3-core.sh;
dump_boot;
write_boot;
