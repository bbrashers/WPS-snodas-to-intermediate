#!/bin/csh -f
if ($#argv < 1 | "$1" =~ -*h*) then
    echo "Usage: $0:t YEAR [MO [DY [UN]]]"
    echo "Where"
    echo "  YEAR   4 digits"
    echo "  MO     2 digits"
    echo "  DY     2 digits"
    echo "  UN     Anything, processes un-masked instead of masked (default)"
    echo ""
    echo "Downloads the SNODAS data for the specified time, and runs "
    echo "snodas-to-intermediate.csh on it, to create raw (uninterpolated) files."
    exit
endif

set yr = $1
if ($#argv > 1) then
    set bmo = $2
    set emo = $bmo
else
    set bmo = 1
    set emo = 12
endif
if ($#argv > 2) then
    set thisday = $3
else
    set thisday = 0
endif

# See note in code about how unmasked data processing looks wrong...

set masked = 1 # 1 = get masked data, 0 = get unmasked data
if ($#argv > 3) set masked = 0  # $masked == false, so means un-masked

foreach mo (`seq -f "%02g" $bmo $emo`)

    if ($thisday == 0) then
	set ndays = `daysinmth $yr $mo`
	set days = (`seq -f "%02g" 1 $ndays`)
    else
	set days = `seq -f "%02g" $thisday $thisday`
    endif

    if !(-e $yr/$mo) mkdir -p $yr/$mo 

    if ($masked) then
	set ftp = ftp://sidads.colorado.edu/DATASETS/NOAA/G02158/masked
    else
	set ftp = ftp://sidads.colorado.edu/DATASETS/NOAA/G02158/unmasked
    endif

    foreach dy ($days)

	set yrmody = $yr$mo$dy
	set mth    = `date +%b -d $yrmody`
	echo Fetching $yr-$mo-$dy

	if ($masked) then
	    if !(-e $yr/$mo/SNODAS_$yrmody.tar) then
		wget -nv $ftp/$yr/${mo}_$mth/SNODAS_$yrmody.tar
		mv -v SNODAS_$yrmody.tar $yr/$mo
	    endif

	    snodas-to-intermediate.csh $yr/$mo/SNODAS_$yrmody.tar

	else # unmasked
	    if !(-e $yr/$mo/SNODAS_unmasked_$yrmody.tar) then
		wget -nv $ftp/$yr/${mo}_$mth/SNODAS_unmasked_$yrmody.tar
		mv -v SNODAS_unmasked_$yrmody.tar $yr/$mo
	    endif

	    snodas-to-intermediate.csh $yr/$mo/SNODAS_unmasked_$yrmody.tar
	    
	endif
	echo ""
    end
end

