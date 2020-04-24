#!/bin/csh -f
if ($#argv < 1 | "$1" =~ -*h*) then
    echo "Usage: $0:t path/to/SNODAS_*.tar"
    echo ""
    echo "Runs snodas-to-intermediate on the given file."
    exit
endif

set loc = /wrf/wrf.init/SNODAS

foreach type (masked unmasked) 
    foreach param (SNOW SNOWH)
	if !(-e $loc/$type/raw/$param) mkdir -p $loc/$type/raw/$param
    end
end

set tarfile = $1
# tarfile names are like this:
# SNODAS_20110117.tar
# SNODAS_unmasked_20110117.tar
set yr = `echo $tarfile:t | tr _ "\n" | grep tar | cut -c 1-4`
set mo = `echo $tarfile:t | tr _ "\n" | grep tar | cut -c 5-6`
set dy = `echo $tarfile:t | tr _ "\n" | grep tar | cut -c 7-8`
echo " Extracting"
tar xvf $tarfile \*1034\*.dat.gz \*1036\*.dat.gz

foreach file (`ls -1 | grep us | grep $yr$mo$dy | grep gz`)
    gunzip $file
    $loc/snodas-to-intermediate $file:r  # hour of analysis is 0500 UTC
    if ($file =~ *1034*) mv -v SNOW:$yr-$mo-$dy*  $loc/masked/raw/SNOW
    if ($file =~ *1036*) mv -v SNOWH:$yr-$mo-$dy* $loc/masked/raw/SNOWH
    rm $file:r
end
foreach file (`ls -1 | grep zz | grep $yr$mo$dy | grep gz`)
    gunzip $file
    $loc/snodas-to-intermediate $file:r  # hour of analysis is 0500 UTC
    if ($file =~ *1034*) mv -v SNOW:$yr-$mo-$dy*  $loc/unmasked/raw/SNOW
    if ($file =~ *1036*) mv -v SNOWH:$yr-$mo-$dy* $loc/unmasked/raw/SNOWH
    rm $file:r
end
