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

# Extremely barebones XML parsing
read_dom () {
    local IFS=\>
    read -d \< ENTITY CONTENT
}

# flags/indicators (state machine stuff)
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

# argument processing
if [ $# -ne 2 ] ; then
  echo "usage: $(basename $0) image-file xml-file"
  exit 1
fi

IMG_FILE="$1"
XML_FILE="$2"

# argument validation
if [ ! -f "$IMG_FILE" ]; then
  echo "ERROR: no such file: $IMG_FILE"
  exit 1
fi
if [ ! -f "$XML_FILE" ]; then
  echo "ERROR: no such file: $XML_FILE"
  exit 1
fi

# alright, let's do this
echo "Image file: $IMG_FILE"
echo "XML file:   $XML_FILE"

while read_dom; do
  # echo "$ENTITY => $CONTENT"
  if [[ $ENTITY =~ ^SCSITarget.*$ ]]; then
    # found a target
    TARGET=$(echo $ENTITY | cut -d'"' -f 2)
    TARGET=$((TARGET))
    echo "Found target: $TARGET"
  fi
  # echo $TARGET
  # is it one we actually care about?
  if [ $TARGET -ne 999 ]; then
    # not if it's disabled tho
    if [ "$ENTITY" = "enabled" -a "$CONTENT" = "false" ]; then
      echo "Disabled target; ignoring"
      TARGET=999
      echo ""
    else
      # found target, now we look for sdSectorStart
      LOOKING_FOR_SECTOR_START=1
    fi

    if [ $LOOKING_FOR_SECTOR_START -eq 1 -a "$ENTITY" = "sdSectorStart" ]; then
      # found sdSectorStart, now we look for scsiSectors
      SECTOR_START=$((CONTENT))
      echo "Found sector start: $SECTOR_START"
      LOOKING_FOR_SECTOR_START=0
      LOOKING_FOR_SECTOR_COUNT=1
    fi

    if [ $LOOKING_FOR_SECTOR_COUNT -eq 1 -a "$ENTITY" = "scsiSectors" ]; then
      # fouond scsiSectors, now we look for bytesPerSector
      SECTOR_COUNT=$((CONTENT))
      echo "Found sector count: $SECTOR_COUNT"
      LOOKING_FOR_SECTOR_COUNT=0
      LOOKING_FOR_BYTES_PER_SECTOR=1
    fi

    if [ $LOOKING_FOR_BYTES_PER_SECTOR -eq 1 -a "$ENTITY" = "bytesPerSector" ]; then
      # ok we should have everything we need now
      BYTES_PER_SECTOR=$((CONTENT))
      echo "Found bytes per sector: $BYTES_PER_SECTOR"
      LOOKING_FOR_BYTES_PER_SECTOR=0
      READY=1
    fi

    # do we have everything we need?
    if [ $READY -eq 1 ]; then
      READY=0
      CALCULATED_FILE_SIZE=$((SECTOR_COUNT * BYTES_PER_SECTOR))
      # construct filename and appropriate dd command
      OUT_FILE="HD${TARGET}0_$BYTES_PER_SECTOR.hda"
      COMMAND="dd if=$IMG_FILE of=$OUT_FILE bs=$BYTES_PER_SECTOR skip=$SECTOR_START count=$SECTOR_COUNT"
      echo "writing SCSI target $TARGET to \`$OUT_FILE' using:"
      echo "$ $COMMAND"
      $COMMAND
      echo "file should be $CALCULATED_FILE_SIZE in size"
      ACTUAL_FILE_SIZE=$(stat -c%s "$OUT_FILE")
      if [ $ACTUAL_FILE_SIZE -eq $CALCULATED_FILE_SIZE ]; then
        echo "it is"
      else
        ZEROS_TO_PAD=$((CALCULATED_FILE_SIZE - ACTUAL_FILE_SIZE))
        echo "it is NOT! Padding with $ZEROS_TO_PAD zeros."
        truncate -s $ZEROS_TO_PAD /tmp/padding$$
        cat /tmp/padding$$ >> "$OUT_FILE"
        rm -f /tmp/padding$$
      fi
      echo "done"
      echo ""
    fi
  fi
done < "$XML_FILE"

# that's it, we're done here
echo "ALL DONE"
