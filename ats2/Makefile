########################################################################
# Makefile for the ATS2 (native, "brutal half") side of MT.
#
# Requires ATS2/Postiats (patscc), e.g. `brew install ats2-postiats`.
# ATS2 is stable (0.4.2 since 2020) — no vendoring needed, unlike the
# alpha ATS3 toolchain in vendor/XATSHOME.
########################################################################

PATSCC=patscc
# ATS_MEMALLOC_LIBC: back linear heap allocation (arrayptr & friends)
# with plain malloc/free.
CFLAGS=-O2 -DATS_MEMALLOC_LIBC

all:: build/smoke

build/%: src/%.dats
	@mkdir -p build
	$(PATSCC) $(CFLAGS) -o $@ $< -cleanaft

smoke:: build/smoke
	./build/smoke

clean:: ; rm -rf build

.PHONY: all smoke clean
