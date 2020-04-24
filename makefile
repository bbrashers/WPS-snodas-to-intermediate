FC      = pgf90

FFLAGS  = -fast -g
#FFLAGS += -Mbounds                # for bounds checking/debugging
#FFLAGS += -Bstatic_pgi            # to use static PGI libraries
#FFLAGS += -Bstatic                # to use static netCDF libraries
#FFLAGS += -mp=nonuma -nomp        # fix for "can't find libnuma.so"

PROG    = snodas-to-intermediate

TODAY   = 2015-03-05
VERSION = 1.3

%.o : %.f90
	$(FC) -c $(FFLAGS) $< -o $@

$(PROG): $(PROG).o
	$(FC) $(FFLAGS) -o $(PROG) $(PROG).o

distro: 
	zip $(PROG)_v$(VERSION)_$(TODAY).zip \
		$(PROG) *.f90 *.csh add_time daysinmth makefile README.md

clean:
	rm $(PROG) *.o 

