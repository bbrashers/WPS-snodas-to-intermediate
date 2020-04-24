program snodas2metgrid

! snodas2metgrid VERSION 1.0 2013-12-22
!
! Written by Bart Brashers, ENVIRON (bbrashers@environcorp.com), Nov 2013.
! Converts the data found at ftp://sidads.colorado.edu/DATASETS/NOAA/G02158
! to metgrid-ready format (WPS intermediate format).
! See http://nsidc.org/data/docs/noaa/g02158_snodas_snow_cover_model/
!
! WARNING: This program doesn't seem to work with the UNMASKED version of 
! SNODAS data, and I can't figure out why.  The western half of the US seems
! to be offset (shifted north).  It could be this code, but it could also be
! the data itself - note that the SNODAS_unmasked_YYYYMMDD.tar files also
! contain data from other time-stamps - which is clearly wrong.  I've started
! at the code and the *.Hdr files for a long time, and I can't see any errors.
! If you find any bugs, please send them to me (bbrashers@environcorp.com).

  implicit none
  integer, external  :: iargc
  integer, parameter :: version = 5   ! Format version (must =5 for WPS format)
  real,    parameter :: bad = -1.e+30 ! value found in FILE:* from NAM12
  real,    parameter :: earth_radius = 6371.

  integer :: year,month,day,hour,outhour, iproj, ilon,jlat
  integer :: param                   ! 1034 = SWE, 1036 = Snow Depth
  integer :: xdim, ydim              ! size of the next 3 arrays
  integer :: i, num_arg

  integer (kind=2),allocatable,dimension(:,:) :: input     ! unscaled values
  real,            allocatable,dimension(:,:) :: output    ! scaled output data
  real,            allocatable,dimension(:,:) :: lats,lons ! output locations

  real :: nlats              ! Number of latitudes north of equator
  real :: xfcst              ! Forecast hour of data
  real :: xlvl               ! Vertical level of data in 2-d array
  real :: startlat, startlon ! Lat/lon of point in array indicated by startloc
  real :: deltalat, deltalon ! Grid spacing, degrees
  real :: dx, dy             ! Grid spacing, km
  real :: xlonc              ! Standard longitude of projection
  real :: tlat1, tlat2       ! True latitudes of projection

  real (kind=8) :: xul, yul          ! Lon,Lat of upper-left gridpoint
  real (kind=8) :: xll, yll          ! Lon,Lat of lower-left gripdoint
  real (kind=8) :: latloninc         ! lat-lon increment (resolution in deg)

  logical :: is_wind_grid_rel        ! Flag indicating whether winds are  
                                     !   relative to source grid (TRUE) or
                                     !   relative to earth (FALSE)
  character (len=8)   :: startloc    ! Which point in array is given by
                                     !   startlat/startlon; set either 
                                     !   to 'SWCORNER' or 'CENTER  '
  character (len=9)   :: field       ! Name of the field
  character (len=24)  :: hdate       ! Valid date for data YYYY:MM:DD_HH:00:00
  character (len=25)  :: units       ! Units of data
  character (len=32)  :: map_source  ! Source model / originating center
  character (len=46)  :: desc        ! Short description of data
  character (len=256) :: arg,filename

  outhour = -99 ! default: use time-stamp hour from filename

  num_arg = command_argument_count() ! FORTRAN 2003 intrinsic: PGI,ifort,gfortran
! num_arg = iargc()    ! FORTRAN 90 external function
! num_arg = NARGS()    ! COMPAQ, Microsoft, or HP compiler

  if (num_arg == 0) call usage

  i = 0
  do while (i < num_arg)
     i = i + 1
     call getarg(i,arg) ! PGI, Intel ifort, or GNU gfortran, or Sun compiler

! Other compilers use similar calls:
!     call getcl(arg)            ! Lahey compiler
!     call getarg(i,arg)         ! COMPAQ compiler
!     call getarg(i,arg,istat)   ! Microsoft compiler
!     call getarg(i,arg)         ! HP compiler: needs +U77 switch to compile

     if (adjustl(arg) == "--help" .or. adjustl(arg) == "-h") then
        call usage
     elseif (adjustl(arg) == "--timestamp" .or. adjustl(arg) == "-t") then
        i = i + 1
        call getarg(i,arg)
        read(arg,*) outhour      ! set hour to this value in output
     else
        filename = arg
     endif
     
  end do
!                            1         2         3         4
!                   1234567890123456789012345678901234567890
! filename is like 'us_ssmv11034tS__T0001TTNATS2011011405HP001.dat'
!                           1034 is SWE = Snow Water Equivalent (m)
!                           1036 is Snow Depth (m)
!                           Each have a scale factor of 1000.

  read(filename(28:31),'(i4.4)') year
  read(filename(32:33),'(i2.2)') month
  read(filename(34:35),'(i2.2)') day
  read(filename(36:37),'(i2.2)') hour
  if (outhour > 0) hour = outhour      ! over-ride with user hour
  read(filename( 9:12),'(i4)')   param ! 1034 or 1036

! These next 5 parmeters can be found in any us*.Hdr and zz*.Hdr file:

  if (filename(1:2) == 'us') then
     xll  = -124.733749999999  ! Minimum x-axis coordinate
     yll  =  24.9495833333334  ! Minimum y-axis coordinate
     xdim = 6935               ! Number of columns
     ydim = 3351               ! Number of rows
  else if (filename(1:2) == 'zz') then
     write(*,*) "*** WARNING *** This is an unmasked file, see comments in code."
     xll  = -130.517083333332  ! Minimum x-axis coordinate
     yll  =  24.0995833333334  ! Minimum y-axis coordinate
     xdim = 8192               ! Number of columns
     ydim = 4096               ! Number of rows
  endif
  latloninc =  0.00833333333333333  ! Horizontal precision

! allocate arrays

  allocate( input(xdim,ydim), output(xdim,ydim) )
  allocate( lats (xdim,ydim), lons  (xdim,ydim) )

  output = bad ! fill with bad value flag

! read in the data

  open(11,file=filename,form='binary',convert='big_endian',status='old')
  read(11) input
  close(11)

! Scale the data, and calculate the locations (note the re-ordering from 
! upper-left starting point to lower-left starting point).  
! Both SWE and Snow Depth have a scale factor of 1000.

  do jlat = 1, ydim
     do ilon = 1, xdim
        lats(ilon, jlat) = yll + latloninc*(jlat-1)
        lons(ilon, jlat) = xll + latloninc*(ilon-1)
        if (input(ilon,ydim-jlat+1) > -99) then
           if (param == 1034) then      ! SWE = Snow Water Equivalent (m)

              ! Convert to Water Equivalent Snow depth (kg m-2) 
              ! Scale factor is /1000, but conversion is *1000.
              output(ilon, jlat) = input(ilon,ydim-jlat+1)

           else if (param == 1036) then ! Snow Depth (m)

              ! Scale factor is /1000.
              output(ilon, jlat) = input(ilon,ydim-jlat+1) / 1000.

           end if
        end if
     end do
  end do

! output the data, see metgrid/src/read_met_module.F90
 
  iproj = 0
  deltalat = latloninc
  deltalon = latloninc

  write(hdate,'(i4.4,"-",i2.2,"-",i2.2,"_",i2.2,":00:00")') year,month,day,hour

! set the filename, field, description, and units

  if (param == 1034) then      ! SWE = Snow Water Equivalent (m)
     filename = 'SNOW:'//hdate(1:13)
     field    = 'SNOW'
     desc     = 'Water equivalent snow depth'
     units    = 'kg m-2'       ! equivalent to 'm'
  else if (param == 1036) then ! Snow Depth (m)
     filename = 'SNOWH:'//hdate(1:13)
     field    = 'SNOWH'
     desc     = 'Snow Depth'
     units    = 'm'
  end if

  write(*,*) "Creating ",trim(filename)
  open(12,file=filename,form='unformatted',convert='big_endian')
  write(12) version

! metadata

  startlat = lats(1,1)
  startlon = lons(1,1)
  startloc = 'SWCORNER'
  xlvl = 200100.

  map_source = 'NSIDC'
  xfcst = 0.
  
  if (iproj .eq. 0) then ! Cylindrical equidistant

     write(12) hdate,xfcst,map_source,field,units,desc,xlvl,xdim,ydim,iproj
     write(12) startloc,startlat,startlon,deltalat,deltalon,earth_radius

  else if (iproj .eq. 1) then ! Mercator

     write(12) hdate,xfcst,map_source,field,units,desc,xlvl,xdim,ydim,iproj
     write(12) startloc,startlat,startlon,dx,dy,tlat1,earth_radius

  else if (iproj .eq. 3) then ! Lambert conformal

     write(12) hdate,xfcst,map_source,field,units,desc,xlvl,xdim,ydim,iproj
     write(12) startloc,startlat,startlon,dx,dy,xlonc,tlat1,tlat2,earth_radius

  else if (iproj .eq. 4) then ! Gaussian

     write(12) hdate,xfcst,map_source,field,units,desc,xlvl,xdim,ydim,iproj
     write(12) startloc,startlat,startlon,nlats,deltalon,earth_radius

  else if (iproj .eq. 5) then ! Polar stereographic

     write(12) hdate,xfcst,map_source,field,units,desc,xlvl,xdim,ydim,iproj
     write(12) startloc,startlat,startlon,dx,dy,xlonc,tlat1,earth_radius

  end if

!  3) WRITE WIND ROTATION FLAG

  is_wind_grid_rel = .false.
  write(12) is_wind_grid_rel

!  4) WRITE 2-D ARRAY OF DATA

  write(12) output
  close(12)

  deallocate( input, output, lats, lons )

  stop
end program snodas2metgrid
!
!*************************************************************************
!
subroutine usage

  write(*,*) 'Usage:  snodas2metgrid infilename'
  write(*,*) 
  write(*,*) 'Example: '
  write(*,*) 'snodas2metgrid us_ssmv11034tS__T0001TTNATS2011011405HP001.dat' 
  write(*,*) 
  write(*,*) 'infilename must be in the local directory, to extract timestamp'
  write(*,*) 'and masked/unmasked from the filename.'
  stop

end subroutine usage
