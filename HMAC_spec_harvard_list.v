Set Implicit Arguments.

(* Require Import Bvector. *)
Require Import List.
Require Import Arith.

Require Import HMAC_functional_prog.
Require Import Integers.
Require Import Coqlib.
Require Import sha_padding_lemmas.
Require Import functional_prog.

Require Import List. Import ListNotations.

Definition Blist := list bool.

Definition compose {A B C : Type} (f : B -> C) (g : A -> B) (x : A) := f (g x).
Notation "f @ g" := (compose f g) (at level 80, right associativity).

Definition splitList {A : Type} (h : nat) (t : nat) (l : list A) : (list A * list A) :=
  (firstn h l, skipn t l).

(*
Definition mkArg (key:list byte) (pad:byte): list byte :=
       (map (fun p => Byte.xor (fst p) (snd p))
          (combine key (sixtyfour pad))).
Definition mkArgZ key (pad:byte): list Z :=
     map Byte.unsigned (mkArg key pad). *)

(* TODO: length proofs (length xs = length ys) *)
Definition BLxor (xs : Blist) (ys : Blist) :=
  map (fun p => xorb (fst p) (snd p)) (combine xs ys).
(* TODO pattern match on tuples? *)

Section HMAC.

(* b = block size
   c = digest (output) size
   p = padding = b - c (fixed) *)
  Variable c p : nat.
  Definition b := (c + p)%nat.

  (* The compression function *)
  Variable h : Blist -> Blist -> Blist.
  (* The initialization vector is part of the spec of the hash function. *)
  Variable iv : Blist.
  (* The iteration of the compression function gives a keyed hash function on lists of words. *)
  Definition h_star k (m : list (Blist)) :=
    fold_left h m k.
  (* The composition of the keyed hash function with the IV gives a hash function on lists of words. *)
  Definition hash_words := h_star iv.

  Check hash_words.
  Check h_star.

  (* NOTE: this is the new design without fpad TODO *)
  Variable splitAndPad : Blist -> list (Blist).

  Definition hash_words_padded : Blist -> Blist :=
    hash_words @ splitAndPad.

  (* ----- *)

  Hypothesis splitAndPad_1_1 :
    forall b1 b2,
      splitAndPad b1 = splitAndPad b2 ->
      b1 = b2.

  (* constant-length padding. *)
  Variable fpad : Blist.

  Definition app_fpad (x : Blist) : Blist :=
    x ++ fpad.
  Definition h_star_pad k x :=
    app_fpad (h_star k x).

  (* TODO fix this *)
  Definition GNMAC k m :=
    let (k_Out, k_In) := splitList c c k in
    h k_Out (h_star_pad k_In m). (* could take head of list *)

  Check GNMAC.
  (*  list bool -> list Blist -> Blist *)
  Check h.
  (* Blist -> Blist -> Blist *)

Check hash_words.               (* list Blist -> Blist *)

  (* The "two-key" version of GHMAC and HMAC. *)
  (* Concatenate (K xor opad) and (K xor ipad) *)
  Definition GHMAC_2K (k : Blist) m :=
    let (k_Out, k_In) := splitList b b k in (* concat earlier, then split *)
      let h_in := (hash_words (k_In :: m)) in
        hash_words_padded (k_Out ++ h_in).

  Definition HMAC_2K (k : Blist) (m : Blist) :=
    GHMAC_2K k (splitAndPad m).

Check HMAC_2K.
(* Blist -> Blist -> Blist *)

(* opad and ipad are constants defined in the HMAC spec. *)
Variable opad ipad : Blist.

Print BLxor.

Definition GHMAC (k : Blist) :=
  GHMAC_2K (BLxor k opad ++ BLxor k ipad).

Definition HMAC (k : Blist) :=
  HMAC_2K (BLxor k opad ++ BLxor k ipad).

Check HMAC.

End HMAC.

(* --------------------------------- *)

Module Equiv.

Check HMAC.

(* HMAC
     : nat ->
       nat ->
       (Blist -> Blist -> Blist) ->
       Blist ->
       (Blist -> list Blist) -> Blist -> Blist -> Blist -> Blist -> Blist *)

(*
Definition c:nat := (SHA256_.DigestLength * 8)%nat.
Definition p:=(32 * 8)%nat.

Parameter sha_iv : Bvector (SHA256_.DigestLength * 8).
Parameter sha_h : Bvector c -> Bvector (c + p) -> Bvector c.
Parameter sha_splitandpad_vector :
  Blist -> list (Bvector (SHA256_.DigestLength * 8 + p)).

(* Parameter fpad : Bvector p. *)
*)

(* TODO does HMAC still need these params? *)
Definition c:nat := (SHA256_.DigestLength * 8)%nat.
Definition p:=(32 * 8)%nat.

Parameter sha_iv : Blist.
Parameter sha_h : Blist -> Blist -> Blist.
Parameter sha_splitandpad : Blist -> list Blist.

(* -------------- *)

Definition asZ (x : bool) : Z := if x then 1 else 0.

Definition convertByteBits (bits : Blist) (byte : Z) : Prop :=
  exists (b0 b1 b2 b3 b4 b5 b6 b7 : bool),
   bits = [b0; b1; b2; b3; b4; b5; b6; b7] /\
   byte =  (1 * (asZ b0) + 2 * (asZ b1) + 4 * (asZ b2) + 8 * (asZ b3)
         + 16 * (asZ b4) + 32 * (asZ b5) + 64 * (asZ b6) + 128 * (asZ b7)).

Inductive bytes_bits_lists : Blist -> list Z -> Prop :=
  | eq_empty : bytes_bits_lists nil nil
  | eq_cons : forall (bits : Blist) (bytes : list Z)
                     (b0 b1 b2 b3 b4 b5 b6 b7 : bool) (byte : Z),
                bytes_bits_lists bits bytes ->
                convertByteBits [b0; b1; b2; b3; b4; b5; b6; b7] byte ->
                bytes_bits_lists (b0 :: b1 :: b2 :: b3 :: b4 :: b5 :: b6 :: b7 :: bits)
                                 (byte :: bytes).

Definition byte_to_64list (byte : byte) : list Z :=
   map Byte.unsigned (HMAC_SHA256.sixtyfour byte).

(* -------- *)

SearchAbout length.
Check splitList.
Eval compute in splitList 0%nat 0%nat [].

Lemma split_append_id : forall {A : Type} (len : nat) (l1 l2 : list A),
                               length l1 = len -> length l2 = len ->
                               splitList len len (l1 ++ l2) = (l1, l2).
Proof.
  induction len; intros h1 h2 l1 l2.
  -
    assert (H: forall {A : Type} (l : list A), length l = 0%nat -> l = []). admit.
    apply H in l1. apply H in l2.
    subst. reflexivity.
  -
    admit.                      (* TODO *)
      
    

Admitted.

(* ------- *)

Lemma inner_fst_equiv : forall (k ip bit_xor : Blist)
                               (K byte_xor : list Z) (IP : byte),
                          ((length k) * 8)%nat = (c + p)%nat ->
                          Zlength K = Z.of_nat SHA256_.BlockSize ->
                          (* TODO: first implies this *)
                          bytes_bits_lists k K ->
                          bytes_bits_lists ip (byte_to_64list IP) ->
                          bit_xor = BLxor k ip ->
                          byte_xor = (map Byte.unsigned
       (HMAC_SHA256.mkArg (map Byte.repr (HMAC_SHA256.mkKey K)) IP)) ->
                          bytes_bits_lists bit_xor byte_xor.

Proof.
  intros k ip bit_xor K byte_xor IP.
  intros k_bitlen k_bytelen k_eq ip_conv_eq bit_res byte_res.
  subst.

  unfold BLxor.

  unfold HMAC_SHA256.mkArg.
  unfold HMAC_SHA256.mkKey.

  rewrite -> k_bytelen. simpl.
  
  unfold HMAC_SHA256.zeroPad.
  SearchAbout Zlength.
  rewrite -> Zlength_correct in k_bytelen.
  inversion k_bytelen.
  unfold Byte.xor. SearchAbout Byte.xor. SearchAbout Z.lxor.

(* might need a lemma about BLxor and Byte.xor *)

Admitted.
  
(*  
  (* --- *)
  
  induction k_eq.
  (* TODO: this particular property is true of key and ipad of any (equal) size, so even
     if they are of fixed size here, that would be a subcase

     maybe not? maybe it's false if key is empty

     key is zero-padded...

     TODO: maybe I should just write a bit version of lennart's spec,
     then slowly convert it to adam's
   *)

  - 
    simpl. 
*)


(* TODO: bytes-bits stuff on SHA *)
(* 
   bytes_bits_lists
     (hash_words_padded sha_h sha_iv sha_splitandpad
        (BLxor k op ++
         hash_words sha_h sha_iv
           (BLxor k ip
            :: sha_splitandpad
                 (b0 :: b1 :: b2 :: b3 :: b4 :: b5 :: b6 :: b7 :: bits))))

     (SHA256_.Hash
        (HMAC_SHA256.mkArgZ (map Byte.repr (HMAC_SHA256.mkKey K)) OP ++
         SHA256_.Hash
           (HMAC_SHA256.mkArgZ (map Byte.repr (HMAC_SHA256.mkKey K)) IP ++
            byte :: bytes)))

  BBL i1 I1 -> ... -> BBL in IN -> BBL (sha i1 ... in) (SHA I1 ... IN)

should be slightly easier -- 
the SHA here is entirely made of wrapped versions of our functions

 *)

Definition concat {A : Type} (l : list (list A)) : list A :=
  flat_map id l.

SearchAbout int.

Print sha_padding_lemmas.generate_and_pad'.
Check sha_padding_lemmas.pad.

Lemma splitandpad_equiv : forall (bits : Blist) (bytes : list Z),
                            bytes_bits_lists
                              (concat (sha_splitandpad bits))
                              (sha_padding_lemmas.pad bytes).
Proof.
  intros bits bytes.
  unfold concat.
  unfold pad.
(* TODO: define sha_splitandpad *)

Admitted.  

Lemma SHA_equiv : forall (bits : Blist) (bytes : list Z),
                    (* assumptions *)
  bytes_bits_lists
    (hash_words_padded sha_h sha_iv sha_splitandpad bits)
    (SHA256_.Hash bytes).

Proof.
  intros bits bytes.
  unfold SHA256_.Hash.
  rewrite -> functional_prog.SHA_256'_eq.
  unfold SHA256.SHA_256.
  unfold hash_words_padded.
  replace ((hash_words sha_h sha_iv @ sha_splitandpad) bits) with
  (hash_words sha_h sha_iv (sha_splitandpad bits)).
  -
    repeat rewrite <- sha_padding_lemmas.pad_compose_equal in *.
    unfold sha_padding_lemmas.generate_and_pad' in *.
    unfold hash_words.
    unfold h_star.

    unfold SHA256.hash_blocks.
    (* unfold SHA256.hash_blocks_terminate. *)
    (* simpl. *)
(* TODO *)

    pose proof splitandpad_equiv as splitandpad_equiv.
    specialize (splitandpad_equiv bits bytes).
    induction splitandpad_equiv.

    +
      simpl.
(* TODO: need sha_h, sha_splitandpad *)
(* TODO: how to use this? *)


Admitted.
  

(* ---------- *)

Theorem HMAC_spec_equiv : forall
                            (K M H : list Z) (OP IP : byte)
                            (k m h : Blist) (op ip : Blist),
  ((length k) * 8)%nat = (c + p)%nat ->
  Zlength K = Z.of_nat SHA256_.BlockSize ->
(* TODO: first implies this *)
  (* TODO: might need more hypotheses about lengths *)
  bytes_bits_lists k K ->
  bytes_bits_lists m M ->
  bytes_bits_lists op (byte_to_64list OP) ->
  bytes_bits_lists ip (byte_to_64list IP) ->
  HMAC c p sha_h sha_iv sha_splitandpad op ip k m = h ->
  HMAC_SHA256.HMAC IP OP M K = H ->
  bytes_bits_lists h H.
Proof.
  intros K M H OP IP k m h op ip.
  intros padded_key_len padded_key_len_byte padded_keys_eq msgs_eq ops_eq ips_eq.
  intros HMAC_abstract HMAC_concrete.

  intros.
  unfold p, c in *.
  simpl in *.

  rewrite <- HMAC_abstract. rewrite <- HMAC_concrete.

  induction msgs_eq.

  (* need to prove that m = [] -> HMAC _ ... _ = [] *)
  -
    admit.

  -
    unfold HMAC.
    unfold HMAC_SHA256.HMAC.

    unfold HMAC_SHA256.INNER.
    unfold HMAC_SHA256.innerArg.
    (* unfold HMAC_SHA256.mkArgZ. *)
    (* Print HMAC_SHA256.mkArg. *)
    (* unfold HMAC_SHA256.mkArg. *)

    unfold HMAC_SHA256.OUTER.
    unfold HMAC_SHA256.outerArg.
    (* unfold HMAC_SHA256.mkArgZ. *)
    (* unfold HMAC_SHA256.mkArg. *)

    unfold HMAC_2K.
    unfold GHMAC_2K.
    Print split_append_id.
    rewrite -> split_append_id.

    (* pose inner_fst_equiv as inner_fst_equiv. *)
    (* apply inner_fst_equiv with (k := k) (ip := ip) (K := K) (IP := IP); auto. *)
    pose SHA_equiv as SHA_equiv.
    

    
(* HMAC IP OP M K =
    H ( K (+) OP      ++
        H ((K (+) IP) ++ M)
      ) 
*)
    

    (* Use these when working on SHA and generate_and_pad *)
    (*
    unfold HMAC_SHA256.OUTER in *.
    unfold SHA256_.Hash in *.
    rewrite -> functional_prog.SHA_256'_eq in *.

    unfold SHA256.SHA_256 in *.
    repeat rewrite <- sha_padding_lemmas.pad_compose_equal in *.
    unfold sha_padding_lemmas.generate_and_pad' in *.
     *)

Abort.

(*
(BLxor k ip
            :: sha_splitandpad
                 (b0 :: b1 :: b2 :: b3 :: b4 :: b5 :: b6 :: b7 :: bits))

 (map Byte.unsigned
              (map
                 (fun p0 : Integers.byte * Integers.byte =>
                  Byte.xor (fst p0) (snd p0))
                 (combine (map Byte.repr (HMAC_SHA256.mkKey K))
                    (HMAC_SHA256.sixtyfour IP))) ++ 
            byte :: bytes)
*)
