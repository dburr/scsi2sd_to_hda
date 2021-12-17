#!/bin/bash
#
# scsi2sd_to_hda.sh - a BASH script to convert SCSI2SD image files to .HDA files
# (compatible with BlueSCSI/RASCSI)
#
# Copyright (c) 2021 Donald Burr
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

read_dom () {
    local IFS=\>
    read -d \< ENTITY CONTENT
}

TARGET=999
# sdSectorStart
LOOKING_FOR_SECTOR_START=0
SECTOR_START=0
# scsiSectors
LOOKING_FOR_SECTOR_COUNT=0
SECTOR_COUNT=0
# bytesPerSector
LOOKING_FOR_BYTES_PER_SECTOR=0
BYTES_PER_SECTOR=0
READY=0

if [ $# -ne 2 ] ; then
  echo "usage: $(basename $0) image-file xml-file"
  exit 1
fi

IMG_FILE="$1"
XML_FILE="$2"

if [ ! -f "$IMG_FILE" ]; then
  echo "ERROR: no such file: $IMG_FILE"
  exit 1
fi

if [ ! -f "$XML_FILE" ]; then
  echo "ERROR: no such file: $XML_FILE"
  exit 1
fi

echo "Image file: $IMG_FILE"
echo "XML file:   $XML_FILE"

while read_dom; do
  # echo "$ENTITY => $CONTENT"
  if [[ $ENTITY =~ ^SCSITarget.*$ ]]; then
    TARGET=$(echo $ENTITY | cut -d'"' -f 2)
    TARGET=$((TARGET))
    echo "Found target: $TARGET"
  fi
  # echo $TARGET
  if [ $TARGET -ne 999 ]; then
    if [ "$ENTITY" = "enabled" -a "$CONTENT" = "false" ]; then
      echo "Disabled target; ignoring"
      TARGET=999
      echo ""
    else
      LOOKING_FOR_SECTOR_START=1
    fi

    if [ $LOOKING_FOR_SECTOR_START -eq 1 -a "$ENTITY" = "sdSectorStart" ]; then
      SECTOR_START=$((CONTENT))
      echo "Found sector start: $SECTOR_START"
      LOOKING_FOR_SECTOR_START=0
      LOOKING_FOR_SECTOR_COUNT=1
    fi

    if [ $LOOKING_FOR_SECTOR_COUNT -eq 1 -a "$ENTITY" = "scsiSectors" ]; then
      SECTOR_COUNT=$((CONTENT))
      echo "Found sector count: $SECTOR_COUNT"
      LOOKING_FOR_SECTOR_COUNT=0
      LOOKING_FOR_BYTES_PER_SECTOR=1
    fi

    if [ $LOOKING_FOR_BYTES_PER_SECTOR -eq 1 -a "$ENTITY" = "bytesPerSector" ]; then
      BYTES_PER_SECTOR=$((CONTENT))
      echo "Found bytes per sector: $BYTES_PER_SECTOR"
      LOOKING_FOR_BYTES_PER_SECTOR=0
      READY=1
    fi

    if [ $READY -eq 1 ]; then
      READY=0
      OUT_FILE="HD${TARGET}0_$BYTES_PER_SECTOR.hda"
      COMMAND="dd if=$IMG_FILE of=$OUT_FILE bs=$BYTES_PER_SECTOR skip=$SECTOR_START count=$SECTOR_COUNT"
      echo "writing SCSI target $TARGET to \`$OUT_FILE' using:"
      echo "$ $COMMAND"
      $COMMAND
      echo "done"
      echo ""
    fi
  fi
done < "$XML_FILE"

echo "ALL DONE"
