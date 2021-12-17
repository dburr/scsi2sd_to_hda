# scsi2sd_to_hda
A utility for converting SCSI2SD images to .HDA files (compatible with RASCSI and BlueSCSI)

# What the heck is this?

Recently I finally finished restoring my beloved SE/30. I'm a major Unix geek, and I have dreamed of being able to run [A/UX](https://www.aux-penelope.com/) on one of my machines. Unfortunately, during its heyday, it was way beyond my starving-student budget. Recently I found the [A/UX SCSI2SD easy install](https://github.com/unxmaal/aux_sdcard) and wanted to give it a try... but I didn't have a SCSI2SD. So I dug into it and figured out that the XML file contains offsets to the various SCSI "devices" in the SD card image file. And I hacked together a script that parses the XML and splits out the various SCSI devices into their own `.hda` files that I could use with my RASCSI and/or BlueSCSI. `;-)`

# Requirements

This script should work with almost any Unix-like system, including Linux and OS X. The only requirement is that you have the `[bash](https://www.gnu.org/software/bash/)` shell.

# Usage

`usage: scsi2sd_to_hda.sh image-file xml-file`

`image-file` is the path to the actual SD card image. (it can also be a `/dev/` file if your SD card is plugged in)

`xml-file` is the path to the XML file containing the SCSI2SD configuration data.

Output will be created using the filename `HDX0.hda` where `X` is the SCSI target number. This filename format is compatible with the [BlueSCSI](https://scsi.blue/) and should also work with the [RASCSI](https://github.com/akuker/RASCSI) (though you will probably want to rename them to a more human-friendly name.)

# Caveats

* This code is pretty rough and tumble. It doesn't modify the source files in any way, so your SCSI2SD source images shouldn't be affected. But the resultant `.hda` images it produces may or may not work.
* SCSI LUNs aren't supported.
* This tool depends on the XML elements being in a certain precise order.
  * `SCSITarget`
  * `sdSectorStart`
  * `scsiSectors`
  * `bytesPerSector`
  If your XML file is in a different order, you'll have to rearrange it. (or fix the script to work with arbitrary orders and submit a pull request `;-)`)
