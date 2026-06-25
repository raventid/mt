(*
** front.dats — MT frontend, slice one.
**
** Reads an MT IL module (docs/il.md, v0) from a file named on argv,
** parses the supported subset, and pretty-prints it back in canonical
** form. Supported subset: one function, class `w`, params, blocks,
** binary instructions (e.g. `add`), and the `ret` terminator. Phi,
** jumps, calls, and the `l`/float classes are deliberately out of
** scope for this slice.
**
** Identifier names are kept as char lists end-to-end: the prelude's
** strn_listize hands back a *linear* list_vt of `cgtz` (nonzero char),
** which to_charlist consumes once and normalizes to a plain list(char)
** — sidestepping both linearity and the cgtz/char parametricity gap.
*)

#include "prelude/almanac/HATS/pre2026_sats.hats"

#include "prelude/HATS/prelude_dats.hats"
#include "prelude/almanac/HATS/pre2026_dats.hats"
#include "prelude/HATS/prelude_JS_dats.hats"
#include "prelude/HATS/prelude_NODE_dats.hats"

(* ****** ****** *)
(* JS glue (front.cats) *)

#extern fun MT_argv1(): strn = $extnam()
#extern fun MT_read_file(path: strn): strn = $extnam()
#extern fun MT_die(msg: strn): void = $extnam()

(* ****** ****** *)
(* AST *)

#typedef charlist = list(char)

datatype token =
| TPunc of char      (* one of ( ) { } , = *)
| TTmp  of charlist  (* %name  *)
| TLbl  of charlist  (* @name  *)
| TGlo  of charlist  (* $name  *)
| TWord of charlist  (* bare alpha run: function/add/ret/w/... *)
| TInt  of sint      (* integer constant *)

datatype rf =
| RTmp of charlist
| RInt of sint

datatype inst =
| IBin of (charlist, charlist, charlist, rf, rf) (* dst, class, op, a, b *)

datatype jump =
| JRet of rf

#typedef param = (charlist, charlist)            (* class, name *)
#typedef block = (charlist, list(inst), jump)    (* label, insts, terminator *)
#typedef func  = (charlist, charlist, list(param), list(block))
                                                 (* retclass, name, params, blocks *)

(* ****** ****** *)
(* linear list_vt(cgtz) -> plain list(char), normalizing the element *)

fun
to_charlist
(xs: list_vt(cgtz)): charlist =
(
case+ xs of
| ~list_vt_nil() => list_nil()
| ~list_vt_cons(c, xs) => list_cons(c, to_charlist(xs))
)

(* ****** ****** *)
(* lexer *)

(* The prelude's char_is* predicates have no JS-target implementation
** (they compile to XATS000_undef), but char comparison IS implemented
** and a char is its integer code — so we roll our own. *)

fun
is_space
(c: char): bool =
(if c = ' ' then true else (if c = '\n' then true else (if c = '\t' then true else c = '\r')))

fun
is_digit
(c: char): bool =
(if c < '0' then false else (if c > '9' then false else true))

fun
is_alpha
(c: char): bool =
(
if c < 'A' then false
else (if c <= 'Z' then true
else (if c < 'a' then false
else (if c <= 'z' then true else false)))
)

fun
is_namechar
(c: char): bool =
(if is_alpha(c) then true else (if is_digit(c) then true else (if c = '_' then true else c = '.')))

fun
take_name
(cs: charlist): (charlist, charlist) =
(
case+ cs of
| list_nil() => @(list_nil(), cs)
| list_cons(c, cs1) =>
  if is_namechar(c)
  then let val (run, rest) = take_name(cs1) in @(list_cons(c, run), rest) end
  else @(list_nil(), cs)
)

fun
take_int
(cs: charlist, acc: sint): (sint, charlist) =
(
case+ cs of
| list_nil() => @(acc, cs)
| list_cons(c, cs1) =>
  if is_digit(c)
  then take_int(cs1, acc * 10 + (ord(c) - ord('0')))
  else @(acc, cs)
)

fun
skip_line
(cs: charlist): charlist =
(
case+ cs of
| list_nil() => cs
| list_cons(c, cs1) => if c = '\n' then cs1 else skip_line(cs1)
)

fun
lex
(cs: charlist): list(token) =
(
case+ cs of
| list_nil() => list_nil()
| list_cons(c, cs1) =>
  (
  case+ c of
  | '#' => lex(skip_line(cs1))
  | '%' => let val (nm, r) = take_name(cs1) in list_cons(TTmp(nm), lex(r)) end
  | '@' => let val (nm, r) = take_name(cs1) in list_cons(TLbl(nm), lex(r)) end
  | '$' => let val (nm, r) = take_name(cs1) in list_cons(TGlo(nm), lex(r)) end
  | '(' => list_cons(TPunc('('), lex(cs1))
  | ')' => list_cons(TPunc(')'), lex(cs1))
  | '{' => list_cons(TPunc('{'), lex(cs1))
  | '}' => list_cons(TPunc('}'), lex(cs1))
  | ',' => list_cons(TPunc(','), lex(cs1))
  | '=' => list_cons(TPunc('='), lex(cs1))
  | _ =>
    if is_space(c) then lex(cs1)
    else (if is_digit(c) then (let val (v, r) = take_int(cs1, ord(c) - ord('0')) in list_cons(TInt(v), lex(r)) end)
    else (if is_alpha(c) then (let val (nm, r) = take_name(cs1) in list_cons(TWord(list_cons(c, nm)), lex(r)) end)
    else (let val () = MT_die("lex: unexpected character") in lex(cs1) end)))
  )
)

(* ****** ****** *)
(* parser: each combinator returns (result, remaining-tokens) *)

fun
chars_eq
(xs: charlist, ys: charlist): bool =
(
case+ xs of
| list_nil() => (case+ ys of list_nil() => true | _ => false)
| list_cons(x, xs) =>
  (case+ ys of list_cons(y, ys) => (if x = y then chars_eq(xs, ys) else false) | _ => false)
)

fun word_eq (cs: charlist, s: strn): bool = chars_eq(cs, to_charlist(strn_listize(s)))

fun
expect_tmp
(ts: list(token)): (charlist, list(token)) =
(
case+ ts of
| list_cons(TTmp(n), ts) => @(n, ts)
| _ => let val () = MT_die("expected %temp") in @(list_nil(), ts) end
)

fun
expect_word
(ts: list(token)): (charlist, list(token)) =
(
case+ ts of
| list_cons(TWord(w), ts) => @(w, ts)
| _ => let val () = MT_die("expected a keyword") in @(list_nil(), ts) end
)

fun
expect_glo
(ts: list(token)): (charlist, list(token)) =
(
case+ ts of
| list_cons(TGlo(n), ts) => @(n, ts)
| _ => let val () = MT_die("expected $global") in @(list_nil(), ts) end
)

fun
expect_punc
(ts: list(token), c: char): list(token) =
(
case+ ts of
| list_cons(TPunc(c2), ts) =>
  if c2 = c then ts else let val () = MT_die("expected punctuation") in ts end
| _ => let val () = MT_die("expected punctuation") in ts end
)

fun
parse_ref
(ts: list(token)): (rf, list(token)) =
(
case+ ts of
| list_cons(TTmp(n), ts) => @(RTmp(n), ts)
| list_cons(TInt(v), ts) => @(RInt(v), ts)
| _ => let val () = MT_die("expected a reference") in @(RInt(0), ts) end
)

fun
parse_inst
(ts: list(token)): (inst, list(token)) = let
  val (dst, ts) = expect_tmp(ts)
  val ts = expect_punc(ts, '=')
  val (cls, ts) = expect_word(ts)
  val (opr, ts) = expect_word(ts)
  val (a, ts) = parse_ref(ts)
  val ts = expect_punc(ts, ',')
  val (b, ts) = parse_ref(ts)
in
  @(IBin(dst, cls, opr, a, b), ts)
end

fun
parse_insts
(ts: list(token)): (list(inst), list(token)) =
(
case+ ts of
| list_cons(TTmp(_), _) => let
    val (i, ts) = parse_inst(ts)
    val (iss, ts) = parse_insts(ts)
  in @(list_cons(i, iss), ts) end
| _ => @(list_nil(), ts)
)

fun
parse_jump
(ts: list(token)): (jump, list(token)) =
(
case+ ts of
| list_cons(TWord(w), ts1) =>
  if word_eq(w, "ret")
  then let val (r, ts2) = parse_ref(ts1) in @(JRet(r), ts2) end
  else let val () = MT_die("expected a terminator") in @(JRet(RInt(0)), ts1) end
| _ => let val () = MT_die("expected a terminator") in @(JRet(RInt(0)), ts) end
)

fun
parse_block
(ts: list(token)): (block, list(token)) =
(
case+ ts of
| list_cons(TLbl(lbl), ts1) => let
    val (insts, ts2) = parse_insts(ts1)
    val (jmp, ts3) = parse_jump(ts2)
  in @(@(lbl, insts, jmp), ts3) end
| _ => let val () = MT_die("expected a @label") in @(@(list_nil(), list_nil(), JRet(RInt(0))), ts) end
)

fun
parse_blocks
(ts: list(token)): (list(block), list(token)) =
(
case+ ts of
| list_cons(TLbl(_), _) => let
    val (b, ts) = parse_block(ts)
    val (bs, ts) = parse_blocks(ts)
  in @(list_cons(b, bs), ts) end
| _ => @(list_nil(), ts)
)

fun
parse_params
(ts: list(token)): (list(param), list(token)) =
(
case+ ts of
| list_cons(TPunc(')'), _) => @(list_nil(), ts)
| _ => let
    val (cls, ts) = expect_word(ts)
    val (nm, ts) = expect_tmp(ts)
    val p = @(cls, nm)
  in
    case+ ts of
    | list_cons(TPunc(','), ts) => let val (ps, ts) = parse_params(ts) in @(list_cons(p, ps), ts) end
    | _ => @(list_cons(p, list_nil()), ts)
  end
)

fun
parse_func
(ts: list(token)): (func, list(token)) = let
  val (kw, ts) = expect_word(ts)
  val () = if word_eq(kw, "function") then () else MT_die("expected 'function'")
  val (rcls, ts) = expect_word(ts)
  val (nm, ts) = expect_glo(ts)
  val ts = expect_punc(ts, '(')
  val (ps, ts) = parse_params(ts)
  val ts = expect_punc(ts, ')')
  val ts = expect_punc(ts, '{')
  val (bs, ts) = parse_blocks(ts)
  val ts = expect_punc(ts, '}')
in
  @(@(rcls, nm, ps, bs), ts)
end

(* ****** ****** *)
(* printer: canonical form (docs/il.md style) *)

fun
print_name
(cs: charlist): void =
(
case+ cs of
| list_nil() => ()
| list_cons(c, cs) => let val () = char_print(c) in print_name(cs) end
)

fun
print_ref
(r: rf): void =
(
case+ r of
| RTmp(n) => let val () = prints("%") in print_name(n) end
| RInt(v) => prints(v)
)

fun
print_param
(p: param): void = let
  val (cls, nm) = p
  val () = print_name(cls)
  val () = prints(" %")
in print_name(nm) end

fun
print_params
(ps: list(param)): void =
(
case+ ps of
| list_nil() => ()
| list_cons(p, list_nil()) => print_param(p)
| list_cons(p, ps) => let val () = print_param(p) val () = prints(", ") in print_params(ps) end
)

fun
print_inst
(i: inst): void =
(
case+ i of
| IBin(dst, cls, opr, a, b) => let
    val () = prints("    %")
    val () = print_name(dst)
    val () = prints(" =")
    val () = print_name(cls)
    val () = prints(" ")
    val () = print_name(opr)
    val () = prints(" ")
    val () = print_ref(a)
    val () = prints(", ")
    val () = print_ref(b)
  in prints("\n") end
)

fun
print_insts
(iss: list(inst)): void =
(
case+ iss of
| list_nil() => ()
| list_cons(i, iss) => let val () = print_inst(i) in print_insts(iss) end
)

fun
print_jump
(j: jump): void =
(
case+ j of
| JRet(r) => let val () = prints("    ret ") val () = print_ref(r) in prints("\n") end
)

fun
print_block
(b: block): void = let
  val (lbl, insts, jmp) = b
  val () = prints("@")
  val () = print_name(lbl)
  val () = prints("\n")
  val () = print_insts(insts)
in print_jump(jmp) end

fun
print_blocks
(bs: list(block)): void =
(
case+ bs of
| list_nil() => ()
| list_cons(b, bs) => let val () = print_block(b) in print_blocks(bs) end
)

fun
print_func
(f: func): void = let
  val (rcls, nm, ps, bs) = f
  val () = prints("function ")
  val () = print_name(rcls)
  val () = prints(" $")
  val () = print_name(nm)
  val () = prints("(")
  val () = print_params(ps)
  val () = prints(") {\n")
  val () = print_blocks(bs)
in prints("}") end

(* ****** ****** *)
(* entry: read -> lex -> parse -> print (the final newline is console_log's) *)

val () = let
  val path = MT_argv1()
  val src = MT_read_file(path)
  val cs = to_charlist(strn_listize(src))
  val toks = lex(cs)
  val (f, _) = parse_func(toks)
  val () = print_func(f)
in
  console_log(the_print_store_flush())
end
