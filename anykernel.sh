# AnyKernel3 - OnePlus 11 (salami)
# osm0sis @ xda-developers

properties() { '
kernel.string=LineageOS KSU-Next+SUSFS Kernel for OnePlus 11
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=salami
device.name2=OP5916L1
supported.versions=14
' ; }

block=/dev/block/bootdevice/by-name/boot;
is_slot_device=1;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;

. tools/ak3-core.sh;
split_boot;
flash_boot;
