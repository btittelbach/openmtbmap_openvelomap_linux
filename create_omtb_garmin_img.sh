#!/bin/zsh
# License: Creative Commons Share Alive 3.0
# Copyright: 2012, Bernhard Tittelbach <xro@realraum.at>
# Thanks to malenki on #osm-de@oftc.net for constructive input and nagging me into making this thing useable in the first place

# Required software:
# - zsh (obviously)
# - 7z
# - mkgmap (preferred) [http://www.mkgmap.org.uk/snapshots/] OR wine
# - gmt linux version [ http://www.anpo.republika.pl/download.html ] OR wine
#

setopt extendedglob
setopt cshnullglob
SCRIPT_NAME=${0:t}
usage()
{
    print "Usage: $SCRIPT_NAME <mtb*.exe|velo*.exe> <TYP-file or TYP-type> [path/to/mkgmap.jar]" > /dev/stderr
    print "       as TYP-type you can choose:" > /dev/stderr
    print "       clas: classic layout - optimized for Vista/Legend series" > /dev/stderr
    print "       thin: thinner tracks and pathes - optimized for Gpsmap60/76 series" > /dev/stderr
    print "       wide: high contrast layout, like classic but with white forest - optimized for Oregon/Colorado dull displays" > /dev/stderr
    print "       hike: like classic layout - but optimized for hiking (does not show mtb/bicycle informations)" > /dev/stderr
    print "       easy: similar to classic layout - but focussed on easy readability hence not showing mtb/bicycle information except routes" > /dev/stderr
    print "       velo: (comes with velomap files) Layout optimized for small GPS screen" > /dev/stderr
    print "       or give the path to your own .TYP style file\n" > /dev/stderr
    exit 1
    # descriptions taken from openmtbmap.org  batch files
}

OMTB_EXE="$1"
TYPFILE="$2"
GMT_CMD==gmt
TMPDIR=${OMTB_EXE:h}/OMTB_tmp/
MKGMAP=(${3}(N) /usr/share/mkgmap/mkgmap.jar(N) /usr/local/share/mkgmap/mkgmap.jar(N) ${^path}/mkgmap.jar(N) )
MKGMAP="${MKGMAP[1]}"

if ! [[ -x $GMT_CMD ]] ; then
    if ! [[ -x =wine ]] ; then
        print "ERROR: You need to either install wine or the gmt linux binary !" > /dev/stderr
        exit 3    
    fi
    # use supplied gmt.exe with wine
    GMT_CMD="wine ./gmt.exe"
fi

if ! [[ -x =7z ]]; then
    print "\nERROR: 7z is not installed, but needed to extract openmtbmap downloads !"
    exit 3
fi

[[ -z $TYPFILE || ! -f $OMTB_EXE ]] && usage

if [[ ${OMTB_EXE:t} == mtb* ]]; then
    OMTBORVELO=openmtbmap
    OMTB_NAME="${OMTB_EXE:t:r:s/mtb/}"
elif [[ ${OMTB_EXE:t} == velo* ]]; then
    OMTBORVELO=openvelomap
    OMTB_NAME="${OMTB_EXE:t:r:s/velo/}"
else
    print "\nERROR: not a openmtbmap.org or openvelomap.org file ?"
    usage
fi    
DSTFILENAME="${OMTB_EXE:h}/${OMTBORVELO}_${OMTB_NAME}.img"
DESC="${OMTBORVELO}_${OMTB_NAME}"


if [[ -e $DSTFILENAME ]]; then
    print "\nWarning: the script will create (overwrite) $DSTFILENAME"
    print "         but $DSTFILENAME already exists."
    read -q "?Continue and overwrite ? [y/N] " || exit 0
    print ""
fi

if [[ -d $TMPDIR ]] ; then
    print "\nWarning: the script will extract $OMTB_EXE to $TMPDIR,"
    print "         but $TMPDIR exists. If you are continuing after an error and"
    print "         $TMPDIR was created by a previous run, you may safely press [y]"
    print "         If not, you should say [n] and delete or backup it first"
    read -q "?Continue ? [y/N] " || exit 0
    print ""
else 
    mkdir $TMPDIR || exit 1
fi

FIMG=(${TMPDIR}/6<000-999>0000.img(N))
if ! [[ -f ${FIMG[1]} ]] ; then 
    print "Extracting $OMTB_EXE ..."
    7z x -y -o$TMPDIR ${OMTB_EXE} &>/dev/null || exit 1
    FIMG=(${TMPDIR}/6<000-999>0000.img(N[1]))
    [[ -f ${FIMG[1]} ]] || {print "\nERROR, could not find 6*.img file after extracting $OMTB_EXE" >/dev/stderr ; exit 1}
fi
if [[ -f $TYPFILE ]] ; then
    TYPFILE=${TYPFILE:A}
else
    TYPFILE=( "${TMPDIR}/"(#i)${TYPFILE}*.typ(N:A))
    TYPFILE=${TYPFILE[1]}
fi

trap "cd '$PWD'" EXIT
cd $TMPDIR || exit 5
TMPDIR="$PWD"

if ! [[ -n $TYPFILE && -f $TYPFILE ]] ; then
    print "\nERROR: Typfile $TYPFILE not found" > /dev/stderr
    print "       please choose your own file or one of these types: "  *.(#l)TYP(N:r)  > /dev/stderr
    exit 2
fi

print "using display-typefile: $TYPFILE"
cp $TYPFILE 01002468.TYP || exit 4
FID=${${FIMG:t}[1][1,4]}
print using FID $FID

$GMT_CMD -wy $FID 01002468.TYP
if [[ -n $MKGMAP && -f $MKGMAP ]]; then
    print "using mkgmap, building address search index..."
    #java -Xmx1000M -jar mkgmap.jar --family-id=$FID --index --description="$DESC" --series-name="$DESC" --family-name="$DESC" --show-profiles=1  --product-id=1 --gmapsupp 6*.img 7*.img 01002468.TYP
    java -Xmx3000M -jar "$MKGMAP" --family-id=$FID --index --description="$DESC" --series-name="$DESC" --family-name="$DESC" --show-profiles=1  --product-id=1 --gmapsupp [67]*.img 01002468.TYP || exit 7
    mv (#i)gmapsupp.img "${DSTFILENAME}"
else
    print "mkgmap not found, using gmt..."
    $GMT_CMD -j -o "${DSTFILENAME}" -f $FID -m "$DESC" 6*.img 7*.img 01002468.TYP || exit 7
fi
rm -R "$TMPDIR"
print "\nSuccessfully created ${DSTFILENAME}"
