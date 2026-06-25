########################################################################
# Makefile for the ATS3 side of MT.
#
# Recipe cribbed from XATSHOME's own examples
# (contrib/githwxi/pground/proj001@250424/misc012): a runnable program
# is the JS runtime files concatenated with the compiler's stdout.
########################################################################

CAT=cat
NODE=node

# The XATS2JS compiler resolves `#include "prelude/..."` against this
# environment variable; it must point at the vendored XATSHOME tree.
XATSHOME := $(abspath ../vendor/XATSHOME)
export XATSHOME

XATS2JSD=$(XATSHOME)/xassets/JS/xats2js

# Two builds of the same ATS3->JS compiler ship in XATSHOME; we follow
# upstream examples and default to the ats2-hosted one. NB: despite an
# upstream comment about TRO, NEITHER build compiles tail calls into
# jumps (probe-verified 2026-06-10; the 2020-era xats2js that did TRO,
# per ATS-Xanadu docgenx/NOTES/HX-2020-11-22.txt, predates jsemit01).
# Deep loops must go through the prelude's trec/stream combinators,
# whose JS-target implementations are native while-loops in
# runtime/srcgen2_prelude.js (see prelude/DATS/CATS/JS/).
XATS2JS=$(XATS2JSD)/xats2js_jsemit01_ats2_opt1.js
#XATS2JS=$(XATS2JSD)/xats2js_jsemit01_ats3_opt1.js

RUNTIME=\
  $(XATS2JSD)/runtime/xats2js_js1emit.js \
  $(XATS2JSD)/runtime/srcgen2_precats.js \
  $(XATS2JSD)/runtime/srcgen2_prelude.js \
  $(XATS2JSD)/runtime/srcgen2_prelude_node.js

########################################################################

all:: build/smoke_out.js
all:: build/front_out.js

# A runnable bundle = JS runtime, then the optional per-program .cats
# glue (FFI counterparts for $extnam), then the compiler's stdout.
build/%_out.js: src/%.dats
	@mkdir -p build
	$(CAT) $(RUNTIME) > $@
	@[ -f src/$*.cats ] && $(CAT) src/$*.cats >> $@ || true
	$(NODE) --stack-size=8801 $(XATS2JS) $< >> $@ || (rm -f $@; exit 1)

# Run with stack headroom: generated code has no tail-call elimination,
# so even bounded recursion wants a deeper stack than Node's default.
smoke:: build/smoke_out.js
	$(NODE) --stack-size=8800 $<

# Round-trip a .ssa file through the frontend (defaults to the corpus).
FILE ?= ../tests/il/add.ssa
front:: build/front_out.js
	$(NODE) --stack-size=8800 build/front_out.js $(FILE)

# Regression check: the frontend's output, fed back in, must be
# byte-stable (parse . print is idempotent). Proves lexer+parser+printer.
roundtrip:: build/front_out.js
	@$(NODE) --stack-size=8800 build/front_out.js ../tests/il/add.ssa > build/rt1.ssa
	@$(NODE) --stack-size=8800 build/front_out.js build/rt1.ssa > build/rt2.ssa
	@diff build/rt1.ssa build/rt2.ssa && echo "front: round-trip idempotent OK"

clean:: ; rm -rf build

.PHONY: all smoke front roundtrip clean
