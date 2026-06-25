(*
** smoke.dats — toolchain smoke test for the ATS3 side of MT.
**
** Proves the vendored XATS2JS compiler can build a Node console
** program on this machine, and records the two iteration idioms:
**
**  - Naive self-recursion gets NO tail-call elimination in generated
**    JS (each call is a real stack frame). Keep depths bounded and
**    run with --stack-size headroom.
**  - Million-step loops must use the imperative CBR idiom
**    (var + := via g_state$updts1x), cf. upstream fibo000.dats.
*)

#include
"prelude/almanac/HATS/pre2026_sats.hats"

#include
"prelude/HATS/prelude_dats.hats"
#include
"prelude/almanac/HATS/pre2026_dats.hats"
#include
"prelude/HATS/prelude_JS_dats.hats"
#include
"prelude/HATS/prelude_NODE_dats.hats"

(* recursion probe: bounded depth, no TCO in generated code *)
fun
answer(n: sint): sint =
  if n > 0 then answer(n - 1) else 42

(* loop probe: imperative state-update idiom, safe at any depth *)
fun
count(n: sint): sint =
(
  let
    val () = g_state$updts1x<state>(st0) in st0.1 end
) where
{
//
#typedef state = (sint, sint)
//
var st0: state = (n, 0)
//
#impltmp
state$updts$test1x<state>(st) = (st.0 <= 0)
//
#impltmp
state$updts$updt1x<state>(st) =
let
  val (i, c) = st
in
  if i > 0 then let
    val () = st.0 := i - 1
    val () = st.1 := c + 1 in (*void*) end
end
//
}(*where*)

val () = printsln("mt/ats3 smoke: recursion(10000) = ", answer(10000))
val () = printsln("mt/ats3 smoke: loop(1000000)    = ", count(1000000))
val () = console_log(the_print_store_flush((*void*)))
