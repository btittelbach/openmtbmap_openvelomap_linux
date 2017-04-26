#!/bin/zsh
# License: Creative Commons Share Alike 3.0
# Copyright: 2012, Bernhard Tittelbach <xro@realraum.at>
# Thanks to malenki on #osm-de@oftc.net for constructive input and nagging me into making this thing useable in the first place
# Thanks to Thomas Friebel who fixed some typos and noted that in some extracted openmtbmaps the numbered image files start with 0001 instead of 0000

# Required software:
# - zsh (obviously)
# - 7z  (debian/ubuntu: apt-get install p7zip-full)
# - mkgmap (preferred) [http://www.mkgmap.org.uk/download/mkgmap.html] OR wine
# - optionally: gmt Linux version [ http://www.gmaptool.eu/pl/content/wersja-dla-linuksa ] OR wine
#

setopt extendedglob
setopt cshnullglob
setopt nonomatch #otherwise =executable will abort script if executable not found

SCRIPT_NAME=${0:t}
usage()
{
    print "\nUsage: $SCRIPT_NAME [options] <mtb*.exe|velo*.exe> <TYP-file or TYP-style>" > /dev/stderr
    print "   as TYP-style you can choose:" > /dev/stderr
    if [[ $OMTBORVELO != openvelomap ]]; then
    print "   For OpenMTB-maps:" > /dev/stderr
    print "     clas: Classic layout - optimized for Vista/Legend series." > /dev/stderr
    print "     thin: Thinner tracks and pathes - optimized for Gpsmap60/76 series." > /dev/stderr
    print "     wide: High contrast layout, like classic but with white forest - optimized for Oregon/Colorado displays." > /dev/stderr
    print "     hike: Like classic layout - but optimized for hiking (does not show mtb/bicycle informations)." > /dev/stderr
    print "     easy: Similar to classic layout - focused on easy readability, not showing mtb/bicycle information except routes." > /dev/stderr
    fi
    if [[ $OMTBORVELO != openmtbmap ]]; then
    print "   For OpenVelo-maps:" > /dev/stderr
    print "     velo: Layout optimized for small GPS screen" > /dev/stderr
    print "     velw: Wide layout optimized for high DPI screens like Oregon" > /dev/stderr
    print "     race: Clean layout for road biking. No buildings or features." > /dev/stderr
    fi
    print "   or give the path to your own .TYP style file" > /dev/stderr
    print "\nOptions:" > /dev/stderr
    print "   -g <path/to/gmt>" > /dev/stderr
    print "   -m <path/to/mkgmap.jar>" > /dev/stderr
    print "   -o <path/to/outputdir>\n" > /dev/stderr
    exit 1
    # descriptions taken from openmtbmap.org  batch files
}

# convert decimal number to octal number and output as ascii character
chr ()
{
  printf \\$(($1/64*100+$1%64/8*10+$1%8))
}

# use linux-gmt or wine-gmt or set manually
# thanks to luhk @ github for pioniering this
# depends on global variable GMT_CMD
setFID()
{
  local FID=$(($1))
  local FIDFILE="$2"
  if [[ -n $GMT_CMD ]]; then
      ${=GMT_CMD} -wy ${FID} ${FIDFILE}
  else
      #DIY
      #This is adapted from http://pinns.co.uk/osm/typformat.html
      HIGH_BYTE=$[FID/256]
      LOW_BYTE=$[FID%256]
      chr $HIGH_BYTE | dd of=${FIDFILE} bs=1 seek=48 count=1 conv=notrunc &> /dev/null
      chr $LOW_BYTE | dd of=${FIDFILE} bs=1 seek=47 count=1 conv=notrunc &> /dev/null
  fi
}

zparseopts -A ARGS_A -D -E -- "g:" "m:" "o:"
OMTB_EXE="$1"
TYPFILE="$2"

if [ $# -lt 2 ]; then
    usage
elif [ ! -f "$OMTB_EXE" ]; then
    echo "ERROR: Input map file does not exist (or is not a file)!" > /dev/stderr
    exit 2
fi

if [[ ${OMTB_EXE:t} == mtb* ]]; then
    OMTBORVELO=openmtbmap
    OMTB_NAME="${OMTB_EXE:t:r:s/mtb/}"
elif [[ ${OMTB_EXE:t} == velo* ]]; then
    OMTBORVELO=openvelomap
    OMTB_NAME="${OMTB_EXE:t:r:s/velo/}"
elif [[ -n ${OMTB_EXE:t} ]]; then
    print "\nERROR: Not a openmtbmap.org or openvelomap.org file ?" > /dev/stderr
    usage
fi

GMT_CMD=( ${ARGS_A[-g]}(.N,@-.) ${^path}/gmt(.N,@-.) )
GMT_CMD="${GMT_CMD[1]:a}"
# if wine exists, this expands into e.g. /usr/bin/wine, otherwhise it will remain as string =wine
# advantage over which wine is, that it outputs only one result, namely the executable that a call to wine on the CL would actually use
WINE_EXE==wine

# NB: If mkgmap is not found, we fall back to using gmt later.
MKGMAP=( ${ARGS_A[-m]}(.N,@-.) /usr/share/mkgmap/mkgmap.jar(.N,@-.) /usr/local/share/mkgmap/mkgmap.jar(.N,@-.) /usr/share/java/mkgmap.jar(.N,@-.) /usr/share/java/mkgmap/mkgmap.jar(.N,@-.) ${^path}/mkgmap.jar(.N,@-.) )
MKGMAP="${MKGMAP[1]:a}"

if ! [[ -x =7z ]]; then
    print "\nERROR: 7z is not installed, but needed to extract openmtbmap downloads !" > /dev/stderr
    exit 3
fi


DESC="${OMTBORVELO}_${OMTB_NAME}"
if [[ -d ${ARGS_A[-o]} ]]; then
    DSTFILENAME="${ARGS_A[-o]:A}/${DESC}.img"
    TMPDIR=${ARGS_A[-o]:A}/OMTB_tmp
else
    DSTFILENAME="${OMTB_EXE:A:h}/${DESC}.img"
    TMPDIR=${OMTB_EXE:A:h}/OMTB_tmp
    [[ -n $ARGS_A[-o] ]] && {print "\nWarning: -o given but ${ARGS_A[-o]} is not a directory.\n         Using ${OMTB_EXE:A:h} instead..\n"}
fi

if ! [[ ( -n $MKGMAP && -x =java ) || -x $WINE_EXE ]]; then
    print "\nERROR: either mkgmap (+java) or wine are required!" > /dev/stderr
    exit 4
fi



if [[ -e $DSTFILENAME ]]; then
    print "\nWarning: The script will create (overwrite) $DSTFILENAME"
    print "         but $DSTFILENAME already exists."
    read -q "?Continue and overwrite ? [y/N] " || exit 0
    print ""
fi

if [[ -e $TMPDIR ]] ; then
    print "\nWarning: The script wants to create directory $TMPDIR, but it already exists."
    if [[ -d $TMPDIR ]] ; then
        print "         If you press [y], $OMTB_EXE will be extracted"
        print "         to $TMPDIR regardless of its contents."
        print "         That's fine if it was created during a previous abortet run of this script."
        print "         Otherwise you should say [n] and move $OMTB_EXE into a clean directory."
        read -q "?Continue ? [y/N] " || exit 0
        print ""
    else
        print "         Please use another output directory and try again."
        exit 1
    fi
else
    mkdir $TMPDIR || exit 1
fi

#Check if extracted files are already present.
FIMG_a=(${TMPDIR}/6<->.img(N[1]))
if [[ -z $FIMG_a ]] ; then
    print "Extracting $OMTB_EXE ..."
    7z e -y -o$TMPDIR ${OMTB_EXE} &>/dev/null || exit 1
    #Check if extraction files are there
    FIMG_a=(${TMPDIR}/6<->.img(N[1]))
    [[ -z $FIMG_a ]] && {print "\nERROR: Could not find 6*.img file after extracting $OMTB_EXE" >/dev/stderr ; exit 1}
fi
if [[ -f $TYPFILE ]] ; then
    TYPFILE="${TYPFILE:A}"
else
    TYPFILE=( "${TMPDIR}/"(#i)${TYPFILE}*.typ(.N:A))
    TYPFILE="${TYPFILE[1]}"
fi

trap "cd '$PWD'" EXIT
cd $TMPDIR || exit 5

if [[ -z $TYPFILE ]] ; then
    print "\nERROR: TYP-file or -style not found" > /dev/stderr
    print "       Please choose your own file or one of these styles: "  *.(#l)TYP(.N:r)  > /dev/stderr
    exit 2
fi

print "Using display-TYP-file: $TYPFILE"
cp $TYPFILE 01002468.TYP || exit 4
FID=${${FIMG_a:t}[1][1,4]}
print "Using FID $FID"

if ! [[ -x "$GMT_CMD" ]] ; then
    #linux gmx not found, looking for alternatives
    if [[ -x $WINE_EXE && -f gmt.exe ]] ; then
        GMT_CMD="wine gmt.exe"
    else
        GMT_CMD=""
    fi
fi

setFID $FID 01002468.TYP

if [[ -n $MKGMAP ]]; then
    print "Using mkgmap, building address search index..."
    #java -Xmx1000M -jar mkgmap.jar --family-id=$FID --index --description="$DESC" --series-name="$DESC" --family-name="$DESC" --show-profiles=1  --product-id=1 --gmapsupp 6*.img 7*.img 01002468.TYP
    if [[ $(grep MemTotal: /proc/meminfo | awk '{print $2}') -gt $((1024*1024*3)) ]]; then
      java -Xmx3000M -jar "$MKGMAP" --family-id=$FID --index --description="$DESC" --series-name="$DESC" --family-name="$DESC" --show-profiles=1  --product-id=1 --gmapsupp [67]*.img 01002468.TYP || exit 7
    else
      java -Xmx1000M -jar "$MKGMAP" --family-id=$FID --index --description="$DESC" --series-name="$DESC" --family-name="$DESC" --show-profiles=1  --product-id=1 --gmapsupp [67]*.img 01002468.TYP || exit 7
    fi
    mv (#i)gmapsupp.img "${DSTFILENAME}" || exit 7
else
    print "mkgmap not found, using gmt..."
    if [[ -z $GMT_CMD ]]; then
        print "Error: gmt not found either."
        exit 3
    fi
    ${=GMT_CMD} -j -o "${DSTFILENAME}" -f $FID -m "$DESC" 6*.img 7*.img 01002468.TYP || exit 7
fi
rm -R "$TMPDIR"
print "\nSuccessfully created ${DSTFILENAME}"
