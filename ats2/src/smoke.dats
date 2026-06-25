(*
** smoke.dats — toolchain smoke test for the ATS2 (native) side of MT.
**
** Exercises the "brutal half" on purpose: A is a *linear* heap array.
** The typechecker enforces ownership — delete the arrayptr_free call
** below and this file stops compiling (unconsumed linear value).
*)

#include "share/atspre_staload.hats"

implement
main0() = let
  val A = arrayptr_make_elt<int>(i2sz(8), 42)
  val x0 = A[0]
  val () = A[0] := x0 - 21
  val () = println!("mt/ats2 smoke: A[0] = ", A[0], " (linear ownership enforced)")
in
  arrayptr_free(A)
end
