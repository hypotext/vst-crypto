Require Import floyd.proofauto.
Require Import sha.sha.
Require Import sha.SHA256.
Require Import sha.spec_sha.
Require Import sha.sha_lemmas.
Require Import sha.bdo_lemmas.
Local Open Scope logic.

Lemma semax_seq_congr:  (* not provable *)
 forall (Espec: OracleKind) s1 s1' s2 s2',
  (forall Delta P R, semax Delta P s1 R <-> semax Delta P s1' R) ->
  (forall Delta P R, semax Delta P s2 R <-> semax Delta P s2' R) ->
 (forall Delta P R, 
    semax Delta P (Ssequence s1 s2) R <->
    semax Delta P (Ssequence s1' s2') R).
Abort.

Definition load8 id ofs :=
 (Sset id
      (Ederef
        (Ebinop Oadd
          (Efield
            (Ederef (Etempvar _ctx (tptr t_struct_SHA256state_st))
              t_struct_SHA256state_st) _h (tarray tuint 8))
          (Econst_int (Int.repr ofs) tint) (tptr tuint)) tuint)).

Lemma sha256_block_load8:
  forall (Espec : OracleKind) 
     (data: val) (r_h: list int) (ctx: val) kv
   (H5 : length r_h = 8%nat),
     semax  
      (initialized _data
         (func_tycontext f_sha256_block_data_order Vprog Gtot))
  (PROP  ()
   LOCAL  (`eq (eval_id _data) (eval_expr (Etempvar _in (tptr tvoid)));
   `(eq ctx) (eval_id _ctx); `(eq data) (eval_id _in);
   `(eq kv) (eval_var _K256 (tarray tuint CBLOCKz)))
   SEP  (`(array_at tuint Tsh (tuints r_h) 0 (Zlength r_h) ctx)))
   (Ssequence (load8 _a 0)
     (Ssequence (load8 _b 1)
     (Ssequence (load8 _c 2)
     (Ssequence (load8 _d 3)
     (Ssequence (load8 _e 4)
     (Ssequence (load8 _f 5)
     (Ssequence (load8 _g 6)
     (Ssequence (load8 _h 7)
         Sskip))))))))
  (normal_ret_assert 
  (PROP  ()
   LOCAL  (`(eq (Vint (nthi r_h 0))) (eval_id _a);
                `(eq (Vint (nthi r_h 1))) (eval_id _b);
                `(eq (Vint (nthi r_h 2))) (eval_id _c);
                `(eq (Vint (nthi r_h 3))) (eval_id _d);
                `(eq (Vint (nthi r_h 4))) (eval_id _e);
                `(eq (Vint (nthi r_h 5))) (eval_id _f);
                `(eq (Vint (nthi r_h 6))) (eval_id _g);
                `(eq (Vint (nthi r_h 7))) (eval_id _h);
   `eq (eval_id _data) (eval_expr (Etempvar _in (tptr tvoid)));
   `(eq ctx) (eval_id _ctx); `(eq data) (eval_id _in);
   `(eq kv) (eval_var _K256 (tarray tuint CBLOCKz)))
   SEP  (`(array_at tuint Tsh (tuints r_h) 0 (Zlength r_h) ctx)))).
Proof.
intros.
unfold load8.
abbreviate_semax.
normalize.
simpl.
normalize.
name a_ _a.
name b_ _b.
name c_ _c.
name d_ _d.
name e_ _e.
name f_ _f.
name g_ _g.
name h_ _h.
name l_ _l.
name Ki _Ki.
name in_ _in.
name ctx_ _ctx.
name i_ _i.
name data_ _data.
abbreviate_semax.
assert (H5': Zlength r_h = 8%Z).
rewrite Zlength_correct; rewrite H5; reflexivity.

do 8 (forward;
         [ entailer!; [|apply ZnthV_map_Vint_is_int]; omega | ]).
forward.  (* skip; *)
entailer. apply prop_right.
revert H0 H1 H2 H3 H4 H6 H7 H8.
clear - H5.
unfold nthi, tuints, ZnthV.
repeat rewrite if_false by (apply Zle_not_lt; computable).
simpl.
repeat (rewrite nth_map' with (d':=Int.zero); [ | omega]).
intros. inv H0; inv H1; inv H2; inv H3; inv H4; inv H6; inv H7; inv H8.
repeat split; auto.
Qed.

Definition get_h (n: Z) :=
    Sset _t
        (Ederef
           (Ebinop Oadd
              (Efield
                 (Ederef (Etempvar _ctx (tptr t_struct_SHA256state_st))
                    t_struct_SHA256state_st) _h (tarray tuint 8))
              (Econst_int (Int.repr n) tint) (tptr tuint)) tuint).

Definition add_h (n: Z) (i: ident) :=
   Sassign
       (Ederef
          (Ebinop Oadd
             (Efield
                (Ederef (Etempvar _ctx (tptr t_struct_SHA256state_st))
                   t_struct_SHA256state_st) _h (tarray tuint 8))
             (Econst_int (Int.repr n) tint) (tptr tuint)) tuint)
       (Ebinop Oadd (Etempvar _t tuint) (Etempvar i tuint) tuint).

Definition add_them_back :=
 [get_h 0, add_h 0 _a,
  get_h 1, add_h 1 _b,
  get_h 2, add_h 2 _c,
  get_h 3, add_h 3 _d,
  get_h 4, add_h 4 _e,
  get_h 5, add_h 5 _f,
  get_h 6, add_h 6 _g,
  get_h 7, add_h 7 _h].

Fixpoint add_upto (k: nat) (u v: list int) {struct k} :=
 match k with
 | O => u
 | S k' => match u,v with
                | u1::us, v1::vs => Int.add u1 v1 :: add_upto k' us vs
                | _, _ => u
                end
 end.

Lemma add_one_back:
 forall Espec Delta Post atoh regs ctx kv (i: nat) more i'
  (i'EQ: i' = (nth i [_a,_b,_c,_d,_e,_f,_g,_h] 1%positive)),
  length atoh = 8%nat ->
  length regs = 8%nat ->
  (forall j, (j<8)%nat -> (temp_types Delta) ! ( nth j [_a, _b, _c, _d, _e, _f, _g, _h] 1%positive) = Some (tuint, true)) ->
  (temp_types Delta) ! _ctx = Some (tptr t_struct_SHA256state_st, true) ->
  (typeof_temp Delta _t) = Some tuint ->
  (i < 8)%nat ->
  @semax Espec (initialized _t Delta)
   (PROP ()
   LOCAL  (`(eq ctx) (eval_id _ctx);
    `(eq (Vint (nthi atoh 0))) (eval_id _a);
    `(eq (Vint (nthi atoh 1))) (eval_id _b);
    `(eq (Vint (nthi atoh 2))) (eval_id _c);
    `(eq (Vint (nthi atoh 3))) (eval_id _d);
    `(eq (Vint (nthi atoh 4))) (eval_id _e);
    `(eq (Vint (nthi atoh 5))) (eval_id _f);
    `(eq (Vint (nthi atoh 6))) (eval_id _g);
    `(eq (Vint (nthi atoh 7))) (eval_id _h);
   `(eq kv) (eval_var _K256 (tarray tuint CBLOCKz)))
   SEP  (`(array_at tuint Tsh (tuints (add_upto (S i) regs atoh)) 0 8 ctx)))
    more
   Post ->
  @semax Espec Delta
   (PROP ()
   LOCAL  (`(eq ctx) (eval_id _ctx);
    `(eq (Vint (nthi atoh 0))) (eval_id _a);
    `(eq (Vint (nthi atoh 1))) (eval_id _b);
    `(eq (Vint (nthi atoh 2))) (eval_id _c);
    `(eq (Vint (nthi atoh 3))) (eval_id _d);
    `(eq (Vint (nthi atoh 4))) (eval_id _e);
    `(eq (Vint (nthi atoh 5))) (eval_id _f);
    `(eq (Vint (nthi atoh 6))) (eval_id _g);
    `(eq (Vint (nthi atoh 7))) (eval_id _h);
   `(eq kv) (eval_var _K256 (tarray tuint CBLOCKz)))
   SEP  (`(array_at tuint Tsh (tuints (add_upto i regs atoh)) 0 8 ctx)))
   (Ssequence (get_h (Z.of_nat i)) (Ssequence (add_h (Z.of_nat i) i') more))
   Post.
Proof.
intros.
subst i'.
unfold get_h.
assert (LENADD: forall k, length (add_upto k regs atoh) = 8%nat). {
clear - H H0.
intro.
forget 8%nat as n.
revert n regs atoh H0 H;
induction k; simpl; intros; auto.
destruct regs as [|r regs]; destruct atoh as [|a atoh]; auto.
destruct n; inv H0; inv H.
simpl. f_equal; auto.
}
eapply semax_seq'.
ensure_normal_ret_assert;
 hoist_later_in_pre.
eapply semax_load_array with (lo:=0)
        (v1:=eval_expr (Efield
              (Ederef (Etempvar _ctx (tptr t_struct_SHA256state_st))
                 t_struct_SHA256state_st) _h (tarray tuint 8)))
         (v2:=eval_expr  (Econst_int (Int.repr (Z.of_nat i)) tint));
     try reflexivity.
     apply H3.
     reflexivity.
     instantiate (2:= (tuints (add_upto i regs atoh))).
     instantiate (1:= 8).
     instantiate (1:= Tsh).
     clear H5.
    intro rho.
    unfold local; super_unfold_lift.
    normalize.
   saturate_local.
  entailer!.
  Focus 1. {
    simpl.
    rewrite Int.signed_repr by repable_signed.
    omega.
  } Unfocus.
  Focus 1. {
    unfold tc_lvalue. unfold typecheck_lvalue. 
    rewrite !binop_lemmas.denote_tc_assert_andp.
    rewrite H2.
    simpl.
    repeat split; auto.
    unfold_lift.
    unfold tuint, tarray, deref_noload.
    simpl.
    destruct (eval_id _ctx rho); try inversion H14; simpl; auto.
    unfold tuint, tarray, deref_noload.
    simpl.
    unfold_lift.
    destruct (eval_id _ctx rho); try inversion H14; simpl; auto.
  } Unfocus.
  Focus 1. {
    unfold tuints, ZnthV.
    simpl; rewrite Int.signed_repr by repable_signed.
   rewrite if_false by omega.
   rewrite (@nth_map' int val _ _ Int.zero).
   apply I.
   rewrite Nat2Z.id.
   rewrite LENADD; auto.
  } Unfocus.
  Focus 1. {
    simpl.  unfold tuints, tuint, tarray, deref_noload.
    simpl.
    unfold_lift.
    destruct (eval_id _ctx rho); try inversion H14; simpl; auto.
    rewrite Int.add_zero.
    cancel.
  } Unfocus.
 
 simpl update_tycon.
 apply extract_exists_pre; intro old.
 autorewrite with subst. clear old.

 unfold add_h.
eapply semax_seq'.
ensure_normal_ret_assert;
 hoist_later_in_pre.
 eapply(@semax_store_array Espec (initialized _t Delta) Tsh 0) with (t := tuint) (contents := (tuints (add_upto i regs atoh))) (lo := 0) (hi := 8);
  try reflexivity.
instantiate (1:= `ctx).
simpl; intros; normalize.

 apply writable_share_top.

{
  intro rho.
  set (i' := nth i [_a, _b, _c, _d, _e, _f, _g, _h] 1%positive).
  unfold PROPx, LOCALx, SEPx.
  unfold local; super_unfold_lift.
  simpl.
  normalize.
  saturate_local.
  apply prop_right; simpl.
  replace (eval_id i' rho) with (Vint (nth i atoh Int.zero)). 
  Focus 2. {
    unfold i'.
    destruct i as [ | [ | [ | [ | [ | [ | [ | [ | ]]]]]]]]; try assumption.
    clear - H4; omega.
  } Unfocus.
  unfold tc_lvalue, typecheck_lvalue.
  rewrite !binop_lemmas.denote_tc_assert_andp.
  replace ((temp_types (initialized _t Delta)) ! _ctx) with (Some (tptr t_struct_SHA256state_st, true)).
  Focus 2. {
    clear - H3 H2.
    unfold typeof_temp in H3.
    unfold initialized.
    destruct ((temp_types Delta) ! _t) eqn:?; inversion H3.
    destruct p; inv H0. unfold temp_types.
    destruct Delta. destruct p. destruct p.
    unfold fst, snd. rewrite PTree.gso. auto.
    cbv. intros. inversion H.
  } Unfocus.
  simpl.
  unfold_lift.
  repeat split; auto.
  + unfold tuint, tarray, deref_noload.
    simpl.
    destruct (eval_id _ctx rho); try inversion Heqv; simpl; auto.
  + unfold tuint, tarray, deref_noload.
    simpl.
    destruct (eval_id _ctx rho); try inversion Heqv; simpl; auto.
  + unfold tc_expr, typecheck_expr.
    replace ((temp_types (initialized _t Delta)) ! _t) with (Some (tuint,true)).
    Focus 2. {
      clear - H3.
      unfold typeof_temp in H3.
      unfold initialized.
      destruct ((temp_types Delta) ! _t); inv H3.
      destruct p; inv H0. unfold temp_types.
      destruct Delta. destruct p. destruct p.
      unfold fst, snd. rewrite PTree.gss. auto.
    } Unfocus.
    rewrite !binop_lemmas.denote_tc_assert_andp.
    simpl.
    rewrite <- (expr_lemmas.initialized_ne Delta i' _t).
    specialize (H1 _ H4).
    unfold i'.
    rewrite H1. 
    repeat split; auto.
    cbv. intros.  destruct i as [ | [ | [ | [ | [ | [ | [ | [ | [ | ] ]]]]]]]]; inv H17.
}

{
 instantiate (1:= `(Vint (Int.repr (Z.of_nat i)))).
 intro rho.
 set (i' := nth i [_a, _b, _c, _d, _e, _f, _g, _h] 1%positive).
 unfold PROPx, LOCALx, SEPx.
 unfold local; super_unfold_lift.
 simpl.
 normalize.
 saturate_local.
 apply prop_right; simpl.
 destruct (eval_id _ctx rho) eqn:?; try (contradiction H16).
 simpl.
 repeat split; auto.
 + f_equal.
   f_equal. rewrite Int.add_zero. reflexivity.
 + omega.
 + omega.
}
 simpl update_tycon.
 unfold replace_nth. 
 eapply semax_pre; try apply H5.
 apply (drop_LOCAL' 0); unfold delete_nth.
(* apply (drop_LOCAL' 0); unfold delete_nth. *)
 intros rho.
 normalize.
 replace (array_at tuint Tsh
     (upd (tuints (add_upto i regs atoh))
        (force_signed_int (Vint (Int.repr (Z.of_nat i))))
        (valinject tuint
           (eval_expr
              (Ecast
                 (Ebinop Oadd (Etempvar _t tuint)
                    (Etempvar
                       (nth i [_a, _b, _c, _d, _e, _f, _g, _h] 1%positive)
                       tuint) tuint) tuint) rho))) 0 8) 
  with (array_at tuint Tsh (tuints (add_upto (S i) regs atoh)) 0 8).
  apply derives_refl.
  replace (force_signed_int (Vint (Int.repr (Z.of_nat i)))) with (Z.of_nat i) by 
    (simpl; rewrite Int.signed_repr by repable_signed; reflexivity).
  replace (valinject tuint (eval_expr
              (Ecast
                 (Ebinop Oadd (Etempvar _t tuint)
                    (Etempvar
                       (nth i [_a, _b, _c, _d, _e, _f, _g, _h] 1%positive)
                       tuint) tuint) tuint) rho)) with (Vint (Int.add (nth i regs Int.zero) (nth i atoh Int.zero))).
  + clear - H H0 H4 LENADD.
apply array_at_ext; intros j ?.
unfold upd, tuints, ZnthV.
 rewrite if_false by omega.
 rewrite (if_false (j<0)) by omega.
 if_tac. subst.
 rewrite Nat2Z.id.
 rewrite (@nth_map' int val _ _ Int.zero).
 f_equal.
 assert (i < length regs /\ length atoh = length regs)%nat.
   split; omega. clear - H2; destruct H2.
 revert atoh regs H H0; induction i; destruct regs, atoh; simpl; intros;
   auto; try omega.
 rewrite <- IHi; auto. omega.
 rewrite LENADD; auto.
 destruct H1.
 apply Z2Nat.inj_lt in H3; try omega.
 change (Z.to_nat 8) with 8%nat in H3.
 assert (i <> Z.to_nat j). contradict H2; subst.
 rewrite Z2Nat.id by omega; auto.
 clear LENADD H2.
 forget 8%nat as k.
 revert i k atoh regs H3 H4 H5 H H0; clear; induction (Z.to_nat j); 
      simpl; intros; destruct i,k,atoh,regs; auto; try omega.
 unfold add_upto; fold add_upto.
 unfold map; fold map. simpl. 
 apply (IHn _ k); auto; try omega.
  + 
 set (i' := nth i [_a, _b, _c, _d, _e, _f, _g, _h] 1%positive).
 unfold PROPx, LOCALx, SEPx.
 simpl.
 unfold_lift.
  rewrite <- H6.
 replace (eval_id i' rho) with (Vint (nth i atoh Int.zero)).
  Focus 2. {
    unfold i'.
    destruct i as [ | [ | [ | [ | [ | [ | [ | [ | ]]]]]]]]; try assumption.
    clear - H4; omega.
  } Unfocus.
 simpl.
 rewrite Int.signed_repr by repable_signed.

unfold tuints, ZnthV. rewrite if_false by (clear; omega).
 rewrite Nat2Z.id.
 rewrite (@nth_map' int val _ _ Int.zero).
 simpl.
 f_equal.
 f_equal.
 clear; revert regs atoh; induction i; destruct regs, atoh; simpl; auto.
 rewrite LENADD; auto.
Qed.

Lemma add_them_back_proof:
  forall (Espec : OracleKind)
     (regs regs': list int) (ctx: val) kv,
     length regs = 8%nat ->
     length regs' = 8%nat ->
     semax  Delta_loop1
   (PROP  ()
   LOCAL 
   (`(eq ctx) (eval_id _ctx);
    `(eq (Vint (nthi regs' 0))) (eval_id _a);
    `(eq (Vint (nthi regs' 1))) (eval_id _b);
    `(eq (Vint (nthi regs' 2))) (eval_id _c);
    `(eq (Vint (nthi regs' 3))) (eval_id _d);
    `(eq (Vint (nthi regs' 4))) (eval_id _e);
    `(eq (Vint (nthi regs' 5))) (eval_id _f);
    `(eq (Vint (nthi regs' 6))) (eval_id _g);
    `(eq (Vint (nthi regs' 7))) (eval_id _h);
    `(eq kv) (eval_var _K256 (tarray tuint CBLOCKz)))
   SEP 
   (`(array_at tuint Tsh (tuints regs) 0 8 ctx)))
   (sequence add_them_back Sskip)
  (normal_ret_assert
   (PROP() LOCAL(`(eq ctx) (eval_id _ctx);
   `(eq kv) (eval_var _K256 (tarray tuint CBLOCKz))) 
    SEP (`(array_at tuint Tsh (tuints (map2 Int.add regs regs')) 0 8 ctx)))).
Proof.
intros.
name a_ _a.
name b_ _b.
name c_ _c.
name d_ _d.
name e_ _e.
name f_ _f.
name g_ _g.
name h_ _h.
name t_ _t.
name ctx_ _ctx.
rename regs' into atoh.

assert (forall j : nat,
   (j < 8)%nat ->
   (temp_types Delta_loop1)
    ! (nth j [_a, _b, _c, _d, _e, _f, _g, _h] 1%positive) = Some (tuint, true)).
 intros; destruct j as [ | [ | [ | [ | [ | [ | [ | [ | ]]]]]]]]; try reflexivity; omega.

assert (forall j : nat,
   (j < 8)%nat ->
   (temp_types (initialized _t Delta_loop1))
    ! (nth j [_a, _b, _c, _d, _e, _f, _g, _h] 1%positive) = Some (tuint, true)).
 intros; destruct j as [ | [ | [ | [ | [ | [ | [ | [ | ]]]]]]]]; try reflexivity; omega.

unfold sequence, add_them_back.
 change (tuints regs) with (tuints (add_upto 0 regs atoh)).
do 8 (simple apply add_one_back; auto; try (clear; omega)).

forward.
apply (drop_LOCAL' 0); unfold delete_nth.
do 8 (apply (drop_LOCAL' 1); unfold delete_nth).
replace (add_upto 8 regs atoh) with  (map2 Int.add regs atoh).
auto.
unfold registers in *.
destruct atoh as [ | a [ | b [ | c [ | d [ | e [ | f [ | g [ | h [ | ]]]]]]]]]; inv H0.
destruct regs as [ | a' [ | b' [ | c' [ | d' [ | e' [ | f' [ | g' [ | h' [ | ]]]]]]]]]; inv H.
reflexivity.
Qed.



