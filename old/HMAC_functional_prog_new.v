Require Import Integers.
Require Import Coqlib.
Require Import Coq.Strings.String.
Require Import Coq.Strings.Ascii.
Require Import List. Import ListNotations.

Require Import SHA256.
Require Import functional_prog.

Require Import HMAC_spec_harvard. (* added *)

(*SHA256: blocksize = 64bytes 
    corresponds to 
    #define SHA_LBLOCK	16
    #define SHA256_CBLOCK	(SHA_LBLOCK*4) *)

Fixpoint Nlist {A} (i:A) n: list A:=
  match n with O => nil
  | S m => i :: Nlist i m
  end.

Definition sixtyfour {A} (i:A): list A:= Nlist i 64%nat.

Definition SHA256_DIGEST_LENGTH := 32.
Definition SHA256_BlockSize := 64%nat. (* 64 bytes = 512 bits *)

Definition Ipad := Byte.repr 54. (*0x36*)
Definition Opad := Byte.repr 92. (*0x5c*)

Print Opad.
Print Byte.repr.
Transparent Byte.repr.
Eval compute in Byte.repr 92.

Module HMAC_FUN.

(*Reading rfc4231 reveals that padding happens on the right*)
Definition zeroPad (k: list Z) : list Z :=
  k ++ Nlist Z0 (SHA256_BlockSize-length k).

Definition mkKey (l:list Z) : list Z :=
  if Z.gtb (Zlength l) (Z.of_nat SHA256_BlockSize)
  then (zeroPad (SHA_256' l)) 
  else zeroPad l.

Definition mkArg (key:list byte) (pad:byte): list byte := 
       (map (fun p => Byte.xor (fst p) (snd p))
          (combine key (sixtyfour pad))).
Definition mkArgZ key (pad:byte): list Z := 
     map Byte.unsigned (mkArg key pad).

(*innerArg to be applied to message, (map Byte.repr (mkKey password)))*)
Definition innerArg (text: list Z) key : list Z :=
  (mkArgZ key Ipad) ++ text.

Definition INNER k text := SHA_256' (innerArg text k).

Definition outerArg (innerRes: list Z) key: list Z :=
  (mkArgZ key Opad) ++ innerRes.

Definition OUTER k innerRes := SHA_256' (outerArg innerRes k).

Definition HMAC txt password: list Z := 
  let key := map Byte.repr (mkKey password) in
  OUTER key (INNER key txt).

Check HMAC.                     (* list Z -> list Z -> list Z *)

Goal HMAC [1,3] [0,0] = [].
  unfold HMAC.
  unfold OUTER.
  unfold outerArg.
  unfold mkArgZ.                 (* note map Byte.unsigned *)
  unfold mkArg.
  
  unfold INNER.
  unfold innerArg.
  unfold mkArgZ.
  unfold mkArg.

  unfold SHA_256'.
  Transparent Int.repr.
  (* simpl. *)
Abort.

Definition HMACString (txt passwd:string): list Z :=
  HMAC (str_to_Z txt) (str_to_Z passwd).

Definition HMACHex (text password:string): list Z := 
  HMAC (hexstring_to_Zlist text) (hexstring_to_Zlist password).

Definition check password text digest := 
  listZ_eq (HMACString text password) (hexstring_to_Zlist digest) = true.

(*a random example, solution obtained via 
  http://www.freeformatter.com/hmac-generator.html#ad-output*)
Goal check "bb" "aa"
      "c1201d3dccfb84c069771d07b3eda4dc26e5b34a4d8634b2bba84fb54d11e265". 
vm_compute. reflexivity. Qed.

Lemma RFC4231_exaple4_2: 
  check "Jefe" "what do ya want for nothing?" 
      "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843".
vm_compute. reflexivity. Qed.

Definition checkHex password text digest := 
  listZ_eq (HMACHex text password) (hexstring_to_Zlist digest) = true.

Lemma RFC6868_example4_2hex: 
  checkHex "4a656665" 
           "7768617420646f2079612077616e7420666f72206e6f7468696e673f"
           "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843".
vm_compute. reflexivity. Qed.

Lemma RFC6868_example4_5hex: 
  checkHex 
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" 
    "54657374205573696e67204c6172676572205468616e20426c6f636b2d53697a65204b6579202d2048617368204b6579204669727374"
    "60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54".
vm_compute. reflexivity. Qed.

Lemma RFC6868_exampleAUTH256_2: 
  checkHex 
  "4a6566654a6566654a6566654a6566654a6566654a6566654a6566654a656665"
  "7768617420646f2079612077616e7420666f72206e6f7468696e673f"
  "167f928588c5cc2eef8e3093caa0e87c9ff566a14794aa61648d81621a2a40c6".
vm_compute. reflexivity. Qed.

End HMAC_FUN.

Check HMAC.

(*
Require Import Bvector.
Set Implicit Arguments.

(* Will override list notation *)
SearchAbout Bvector.
Check b.                        (* ? *)
 SearchAbout HMAC_2K. (* ? *)
(* Where are the extra args coming from? In the H spec,
HMAC_2K : Bvector (b + b) -> Blist -> Bvector c

What's the meaning of Bvector (b c p)?
*)


(* TODO: where's the second param in Adam's?
TODO: SHA equivalence proof *)
Theorem HMAC_equiv : forall (l msg : list Z) (n : nat)
                            (l' : Bvector (n + n)) (m' : Blist),
  HMAC_FUN.HMAC l msg = HMAC_2K l' m'.
Proof.
  intros l m.
 *)