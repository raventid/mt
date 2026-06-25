########################################################################
# Top-level orchestration for MT.
#
#   make vendor   fetch the pinned ATS3 toolchain (XATSHOME)
#   make          build all stages (ATS3, ATS2, Zig)
#   make smoke    compile & run the ATS3 and ATS2 toolchain smoke tests
#   make test     smoke tests + Zig unit tests
########################################################################

VENDOR_REPO=https://github.com/githwxi/XATSHOME.git
# XATSHOME is alpha and moves daily; MT builds against this exact
# commit. Bump deliberately, with `make test` as the gate.
VENDOR_PIN=1cd883d6aba6abd1c05c52d6e5fd49da7598a2be

all:: ats ats2 zig

ats:: vendor/XATSHOME ; $(MAKE) -C ats all
ats2:: ; $(MAKE) -C ats2 all
zig:: ; cd zig && zig build

smoke:: vendor/XATSHOME ; $(MAKE) -C ats smoke
smoke:: ; $(MAKE) -C ats2 smoke
test:: smoke ; $(MAKE) -C ats roundtrip
test:: ; cd zig && zig build test

vendor:: vendor/XATSHOME
vendor/XATSHOME:
	git clone --depth 1 $(VENDOR_REPO) $@
	git -C $@ fetch --depth 1 origin $(VENDOR_PIN)
	git -C $@ checkout $(VENDOR_PIN)

clean::
	$(MAKE) -C ats clean
	$(MAKE) -C ats2 clean
	rm -rf zig/.zig-cache zig/zig-out

.PHONY: all ats ats2 zig smoke test vendor clean
