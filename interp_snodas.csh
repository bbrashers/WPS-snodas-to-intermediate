#!/bin/csh -f
if ($#argv == 0 | "$1" =~ -*h*) then
    echo "Usage: $0:t [-3] YYYY [begMO [endMO]]"
    echo ""
    echo "Options:"
    echo "   -3    Also interpolte to 3-hourly, not just 6-hourly."
    echo ""
    echo "Runs interp-intermediate for the given month(s)."
    exit
endif

set loc = /wrf/wrf.init/SNODAS

set hr3 = 0 # false
if ("$1" == "-3") then
    set hr3 = 1 # true
    shift # get rid of -3
endif

set yr = $1
set bmo = 1
set emo = 12
if ($#argv > 1) then
    set bmo = $2
    set emo = $bmo
    if ($#argv > 2) set emo = $3
endif

set adds = (1 7 13 19) # 6-hourly, add these to 05 to get 06, 12, 18, 00
if ($hr3) set adds = (1 4 7 10 13 16 19 22) # 3-hourly

foreach param (SNOW SNOWH)
    if !(-e $loc/masked/$param) mkdir -p $loc/masked/$param

    foreach mo (`seq -f "%02g" $bmo $emo`)

# special treatment for the first hour of a month:

	set time1 = $yr-$mo-01_05         # today
	set time2 = `add_time $time1 -24` # tomorrow

	set timeI = $yr-$mo-01_00
	set out = $loc/masked/$param/${param}:$timeI

	if !(-e $out) then
	    interp-intermediate -i \
		$loc/masked/raw/$param/${param}:$time1    \
		$loc/masked/raw/$param/${param}:$time2 \
		-o $out
	    echo Created $out
	endif

# now process the rest of the month

	set ndays = `daysinmth $yr $mo`
	foreach dy (`seq -f "%02g" 1 $ndays`)

	    set time1 = $yr-$mo-${dy}_05     # today
	    set time2 = `add_time $time1 24` # tomorrow

	    foreach add ($adds) # add these to get 06, 12, 18, 00

		set timeI = `add_time $time1 $add`
		set out = $loc/masked/$param/${param}:$timeI

		if !(-e $out) then
		    interp-intermediate -i \
			$loc/masked/raw/$param/${param}:$time1    \
			$loc/masked/raw/$param/${param}:$time2 \
			-o $out
		    echo Created $out
		endif
	    end  # foreach add (1 7 13 19)
	end      # foreach dy (`seq -f "%02g" 1 $ndays`)
    end          # foreach mo (`seq -f "%02g" $bmo $emo`)
end              # foreach param (SNOW SNOWH)
