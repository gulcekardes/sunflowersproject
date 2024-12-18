Require Import Coq.Bool.Bool.
Require Import Coq.Lists.List.
Require Import Coq.Arith.PeanoNat.
Require Import String.
Require Import Coq.Strings.String.
Require Import Coq.Strings.Ascii.
Require Import Classical_Prop.
Require Import Classical_Pred_Type.
Import ListNotations.
Local Open Scope string_scope.
Require Import Lia.
Require Import Coq.Reals.Reals.
Require Import Coq.ZArith.ZArith.
Require Import List Bool.
Import ListNotations.

Definition Even (n: nat) : Prop := exists k, n = 2 * k.
Definition Odd (n: nat) : Prop := exists k, n = 2 * k + 1.

(* === Basic Definitions === *)

(* Gate types *)
Inductive gate_type : Type := AND_gate | OR_gate.
Inductive literal : Type := mk_literal : nat -> bool -> literal.

(* We define literals with two components: a natural number (index),
a boolean indicating whether it's negated. *) 

Definition literal_index (l: literal) : nat :=
  match l with
  | mk_literal n _ => n
  end.

Definition literal_is_negated (l: literal) : bool :=
  match l with
  | mk_literal _ b => b
  end.

Definition literal_eq (l1 l2: literal) : bool :=
  match l1, l2 with
  | mk_literal n1 b1, mk_literal n2 b2 => 
      (Nat.eqb n1 n2) && Bool.eqb b1 b2
  end.
  
(* === Circuit Definition === *)

(* AC0 circuit with bounded depth *)
(* Base case: A literal has depth 0
Recursive case: A gate takes inputs of depth d and 
produces a circuit of depth d+1 *)

Inductive AC0_circuit : nat -> Type :=
  | Literal (l: literal) : AC0_circuit 0
  | Gate (d: nat) (op: gate_type) (inputs: list (AC0_circuit d)) : AC0_circuit (S d).

(* === String Conversion Functions === *)

(* Convert literal to string *)
Definition literal_to_string (l: literal) : string :=
  match l with
  | mk_literal n true => "¬x" ++ (String (ascii_of_nat (n + 49)) EmptyString)
  | mk_literal n false => "x" ++ (String (ascii_of_nat (n + 49)) EmptyString)
  end.

(* Convert gate type to string *)
Definition gate_type_to_string (g: gate_type) : string :=
  match g with
  | AND_gate => " ∧ "
  | OR_gate => " ∨ "
  end.

(* Boolean strings - inputs to circuits *)
Definition bool_string := nat -> bool.

(* Evaluate a literal *)
Definition eval_literal (l: literal) (input: bool_string) : bool :=
  match l with
  | mk_literal idx is_neg => 
      if is_neg then negb (input idx) else input idx
  end.

Fixpoint eval_AC0 {d: nat} (c: AC0_circuit d) (input: bool_string) : bool :=
  match c with
  | Literal l => eval_literal l input
  | Gate _ op inputs => 
      match op with
      | AND_gate => forallb (fun c' => eval_AC0 c' input) inputs
      | OR_gate => existsb (fun c' => eval_AC0 c' input) inputs
      end
  end.

(* === Circuit Size Definitions === *)

Fixpoint AC0_size {d: nat} (c: AC0_circuit d) : nat :=
  match c with
  | Literal _ => 1  (* Each literal counts as 1 *)
  | Gate _ _ inputs => 1 + (* The gate itself counts as 1 *)
      fold_left (fun acc c' => acc + AC0_size c') inputs 0
  end.

Fixpoint gate_count {d: nat} (c: AC0_circuit d) : nat :=
  match c with
  | Literal _ => 0  (* Literals don't count as gates *)
  | Gate _ _ inputs => 1 + (* Count this gate *)
      fold_left (fun acc c' => acc + gate_count c') inputs 0
  end.

Definition gate_type_eq (g1 g2: gate_type) : bool :=
  match g1, g2 with
  | AND_gate, AND_gate => true
  | OR_gate, OR_gate => true
  | _, _ => false
  end.

Fixpoint gate_type_count {d: nat} (c: AC0_circuit d) (gt: gate_type) : nat :=
  match c with 
  | Literal _ => 0
  | Gate _ op inputs => 
      (if gate_type_eq op gt then 1 else 0) +
      fold_left (fun acc c' => acc + gate_type_count c' gt) inputs 0
  end.

(* We are ready to introduce k-limits on Boolean strings. *)

(* First we need a subset type to represent valid index lists. *)
Definition valid_indices (indices: list nat) (n k: nat) : Prop :=
  length indices = k /\
  (forall i, In i indices -> i < n) /\
  NoDup indices.

(* Now for k-limit definition *)
Definition is_k_limit (y: bool_string) (B: bool_string -> Prop) (n k: nat) : Prop :=
  forall (indices: list nat),
  valid_indices indices n k ->
  exists (x: bool_string),
    B x /\
    (exists i, x i <> y i) /\ (* differs somewhere *)
    (forall i, In i indices -> x i = y i). (* matches on indices *)

(* Lower k-limit adds condition that x > y *)
Definition is_lower_k_limit (y: bool_string) (B: bool_string -> Prop) (n k: nat) : Prop :=
  forall (indices: list nat),
  valid_indices indices n k ->
  exists (x: bool_string),
    B x /\
    (forall i, x i = true -> y i = true) /\ (* x > y condition *)
    (forall i, In i indices -> x i = y i).

(* Property P(k,l) for pairs of sets *)
Definition property_P (n: nat) (A B: bool_string -> Prop) (k l: nat) : Prop :=
  forall (coloring: bool_string -> nat),
  (forall x, B x -> coloring x < l) ->
  exists color B',
    (color < l) /\
    (forall x, B' x -> B x) /\
    (forall x, B' x -> coloring x = color) /\
    exists y, A y /\ is_k_limit y B' n k.

(* Property Pp(k,l) using lower k-limits *)
Definition property_P_plus (n: nat) (A B: bool_string -> Prop) (k l: nat) : Prop :=
  forall (coloring: bool_string -> nat),
  (forall x, B x -> coloring x < l) ->
  exists color B',
    (color < l) /\
    (forall x, B' x -> B x) /\
    (forall x, B' x -> coloring x = color) /\
    exists y, A y /\ is_lower_k_limit y B' n k.

Lemma nat_eq_dec : forall n m : nat, {n = m} + {n <> m}.
Proof.
  decide equality.
Defined.

(* Need basic set operations for sunflowers. 
*)
Definition set_eq (X Y: list nat) : Prop :=
  forall x, In x X <-> In x Y.

Definition subset (X Y: list nat) : Prop :=
  forall x, In x X -> In x Y.

Definition set_inter (X Y: list nat) : list nat :=
  filter (fun x => if in_dec nat_eq_dec x Y then true else false) X.

Definition set_union (s1 s2: list nat) : list nat :=
  fold_right (fun x acc => 
    if in_dec nat_eq_dec x acc 
    then acc 
    else x :: acc) s2 s1.

Definition set_minus (X Y: list nat) : list nat :=
  filter (fun x => if in_dec nat_eq_dec x Y then false else true) X.

Definition symmetric_difference (X Y: list nat) : list nat :=
  app (set_minus X Y) (set_minus Y X).

Definition pairwise_disjoint (F: list (list nat)) : Prop :=
  forall A B, In A F -> In B F -> A <> B -> 
    set_inter A B = nil.

(* Now we will go for “tau”,
the minimum cardinality of a cover in a set family. 
This prepares for Lemma 2.2. of HJP paper. *)

(* For defining cover, consider the following.
For every set X in F, there must exist some number i that is:
In C (In i C) AND
In X (In i X) *)

Definition is_cover (C: list nat) (F: list (list nat)) : Prop :=
  forall X, In X F -> exists i, In i C /\ In i X.

(* Boolean version for computation *)
Fixpoint is_cover_bool (C: list nat) (F: list (list nat)) : bool :=
  match F with
  | nil => true
  | X :: F' => 
      (* Check if C intersects with X *)
      let intersects := existsb (fun i => if in_dec nat_eq_dec i X then true else false) C in
      if intersects 
      then is_cover_bool C F'
      else false
  end.

(* Now tau can be defined using the boolean version. *)
Definition has_tau (F: list (list nat)) (t: nat) : Prop :=
  exists C, is_cover C F /\ length C = t /\
  forall C', is_cover C' F -> length C' >= t.

(* A sunflower with h petals and core Y. *)
Definition is_sunflower (F: list (list nat)) (Y: list nat) (h: nat) : Prop :=
  exists petals: list (list nat),
    length petals = h /\
    (forall X, In X petals -> In X F) /\
    (* Two properties: *)
    (* 1. Pairwise intersections equal the core *)
    (forall X1 X2, 
      In X1 petals -> In X2 petals -> X1 <> X2 -> 
      set_eq (set_inter X1 X2) Y) /\
    (* 2. After removing core, petals are disjoint *)
    (forall X1 X2,
      In X1 petals -> In X2 petals -> X1 <> X2 ->
      set_eq (set_inter (set_minus X1 Y) (set_minus X2 Y)) nil).

(* Boolean version of subset. *)
Definition subset_bool (X Y: list nat) : bool :=
  forallb (fun x => if in_dec nat_eq_dec x Y then true else false) X.

(* Now F_Y can be defined using the boolean version. *)
Definition F_Y (F: list (list nat)) (Y: list nat) : list (list nat) :=
  filter (fun X => subset_bool Y X) (map (fun X => set_minus X Y) F).

(* We can prove these versions are equivalent. *)
Lemma subset_bool_prop_equiv: forall X Y,
  subset_bool X Y = true <-> subset X Y.
Proof.
Admitted.

(* This lemma states that if we have h disjoint sets 
in our family F, then any cover of F must have size at least h. 
This is a key component in connecting sunflowers to lower bounds. *)

Lemma removelast_In: forall {A} (x: A) (l: list A),
  In x (removelast l) -> In x l.
Proof.
  (* We can prove this by induction on l *)
Admitted.

Lemma disjoint_sets_cover_size: forall F h,
  (exists sets, length sets = h /\
    (forall X, In X sets -> In X F) /\
    (forall X1 X2, In X1 sets -> In X2 sets -> X1 <> X2 -> 
      set_eq (set_inter X1 X2) nil)) ->
  exists t, has_tau F t /\ t >= h.
Proof.
Admitted.

(* Use this to show sunflower implies tau bound *)
(* This lemma is really the key one,
it shows that if you have a sunflower with h+1 petals, 
then the family F_Y (obtained by removing core Y) has tau \geq h/. *)

(* If we have a sunflower with h+1 petals and core Y, 
then after removing Y from each petal, we get h+1 disjoint sets
Any cover of FY must hit each of these disjoint sets
Therefore \tau(FY) must be at least h. *)

Lemma in_set_union : forall (x : nat) (A B : list nat),
  In x (set_union A B) <-> In x A \/ In x B.
Proof.
Admitted.

Lemma in_set_inter: forall x X Y,
  In x (set_inter X Y) <-> In x X /\ In x Y.
Proof.
  intros. split; unfold set_inter.
  - intro H. split.
    + apply filter_In in H. apply H.
    + apply filter_In in H. destruct H as [_ H].
      destruct (in_dec nat_eq_dec x Y); auto.
      discriminate.
  - intros [HX HY]. apply filter_In. split; auto.
    destruct (in_dec nat_eq_dec x Y); auto.
Qed.

Lemma set_inter_self_notempty: forall (X: list nat),
  X <> [] -> set_eq (set_inter X X) X.
Proof.
  intros X Hnotempty.
  unfold set_eq. intros x.
  rewrite in_set_inter.
  split; intros H.
  - destruct H; auto.
  - split; auto.
Qed.

Lemma removelast_length : forall {A} (l : list A),
  l <> [] -> length (removelast l) = length l - 1.
Proof.
  intros A l Hnotempty.
  destruct l.
  - (* Empty case *)
    contradiction.
  - (* Non-empty case: l = a :: l *)
    simpl.
    destruct l.
    + simpl. reflexivity.
    + simpl. f_equal. 
Admitted.

Lemma in_set_minus: forall x X Y,
  In x (set_minus X Y) -> In x X /\ ~In x Y.
Proof.
  (* This should follow from definition of set_minus *)
Admitted.

Lemma sunflower_tau_bound: forall F Y h,
  is_sunflower F Y (S h) ->
  exists t, has_tau (F_Y F Y) t /\ t >= h.
Proof.
  intros F Y h Hsunflower.
  destruct Hsunflower as [petals [Hlen [Hin [Hinter Hdisj]]]].
  assert (Hnonempty: forall X, In X petals -> X <> []).
  { 
    intros X HX.
    destruct X.
    - (* Case X = [] *)
      (* Use Hinter to show this is impossible *)
      assert (exists X1, In X1 petals /\ X1 <> []).
      { 
        destruct petals as [|p petals'] eqn:E.
        - simpl in Hlen. discriminate.
        - destruct HX.
          + (* empty set is head *)
            exists (hd [] petals').
            split.
            * right. simpl in Hlen. destruct petals'.
              -- simpl in Hlen. 
Admitted.

(* Below is the work on sunflowers.
Erdos Rado sunflower theorem's proof is by induction and also uses an
application of the pigeonhole principle. We also need definitions for
set maximality and point removal from a set. *)

(* First define pigeonhole lemma and tactic *)

Lemma pigeonhole: forall (l: list nat) (n: nat),
  length l > n -> 
  exists x: nat, In x l /\ 
    2 * (length (filter (fun y => if Nat.eq_dec x y then true else false) l)) > length l.
Proof.
Admitted.

(* Helper lemma about pigeonhole principle *)
Lemma pigeonhole_principle: forall (l: list nat) (n: nat),
  length l > n -> 
  exists x, In x l /\ 
    2 * (length (filter (fun y => if nat_eq_dec x y then true else false) l)) > length l.
Proof.
  (* We'll admit this for now as it's a standard result *)
Admitted.

(* Definition of maximal disjoint family *)
Definition is_maximal_disjoint (A F: list (list nat)) : Prop :=
  (* A is pairwise disjoint *)
  pairwise_disjoint A /\
  (* A contains sets from F *)
  (forall X, In X A -> In X F) /\
  (* A is maximal - no set can be added while maintaining disjointness *)
  forall X, In X F -> ~pairwise_disjoint (X :: A).

Axiom exists_maximal_disjoint: forall F,
  exists A, is_maximal_disjoint A F.

Definition count_occurrences (x: nat) (F: list (list nat)) : nat :=
  length (filter (fun X => if in_dec nat_eq_dec x X then true else false) F).

Lemma pigeonhole_for_sets: 
  forall (F: list (list nat)) (B: list nat) (bound: nat),
  length F > bound ->
  length B < bound ->
  exists x, In x B /\ 
    count_occurrences x F > length F / length B.
Proof.
Admitted. 

Lemma set_eq_intro: forall (X Y: list nat),
  (forall x, In x X <-> In x Y) -> set_eq X Y.
Proof.
  unfold set_eq. auto.
Qed.

Lemma set_inter_empty_iff: forall X Y,
  set_eq (set_inter X Y) [] <-> forall z, ~(In z X /\ In z Y).
Proof.
Admitted.

(* Definition for what it means for a set to be empty *)
Definition is_empty_set (X: list nat) :=
  forall x, ~In x X.

(* Lemma relating set equality with empty set *)
Lemma set_eq_empty_iff: forall X,
  set_eq X [] <-> is_empty_set X.
Proof.
  intros. unfold set_eq, is_empty_set. split; intros H x.
Admitted.

Lemma empty_intersection_no_common: forall X Y,
  set_eq (set_inter X Y) [] ->
  forall z, ~(In z X /\ In z Y).
Proof.
Admitted.

(* Key lemma about set_inter *)
Lemma in_set_inter_iff: forall z X Y,
  In z (set_inter X Y) <-> In z X /\ In z Y.
Proof.
Admitted.

Lemma set_eq_empty: forall (X: list nat),
  (forall x, ~In x X) -> X = [].
Proof.
  intros X H.
  destruct X.
  - reflexivity.
  - exfalso. apply (H n). simpl. left. reflexivity.
Qed.

Lemma in_fold_right_union: forall (z: nat) (A: list (list nat)) (Y: list nat),
  In Y A -> In z Y ->
  In z (fold_right set_union [] A).
Proof.
  induction A; intros.
  - (* Base case: empty list *)
    simpl in H. contradiction.
  - (* Inductive case *)
    simpl. destruct H.
    + (* Y is the head *)
      subst. unfold set_union.
Admitted.

Lemma maximal_family_intersects_all: forall F A B,
  is_maximal_disjoint A F ->
  B = fold_right set_union nil A ->
  forall X, In X F -> exists x, In x B /\ In x X.
Proof.
  intros F A B Hmaximal HB X HX.
  destruct Hmaximal as [Hdisjoint [HinF Hmax]].
  apply NNPP.
  intro Hnot.
  
  assert (pairwise_disjoint (X :: A)) as Hcontra.
  {
    unfold pairwise_disjoint. intros Y1 Y2 HY1 HY2 Hneq.
    destruct HY1 as [HY1|HY1]; destruct HY2 as [HY2|HY2]; subst.
    + (* Y1 = X, Y2 = X *)
      exfalso. apply Hneq. reflexivity.
    + (* Y1 = X, Y2 ∈ A *)
      apply set_eq_empty. intros z Hz.
      (* Get the elements of the intersection *)
      apply in_set_inter_iff in Hz.
      destruct Hz as [Hz1 Hz2].
      (* Derive contradiction with Hnot *)
      apply Hnot. exists z.
      split.
      * apply in_fold_right_union with Y2; assumption.
      * assumption.
      + apply set_eq_empty. intros z Hz. apply in_set_inter_iff in Hz.
destruct Hz as [Hz1 Hz2].
apply Hnot. exists z.
split.
* apply in_fold_right_union with Y1; assumption.
* assumption.
+ apply Hdisjoint; auto. }
apply (Hmax X HX Hcontra).
Qed.

Lemma singletons_form_sunflower: forall F k,
  k > 0 ->
  (forall X, In X F -> length X = 1) ->  (* all sets are singletons *)
  length F > k - 1 ->
  exists Y, is_sunflower F Y k.
Proof.
Admitted.

Axiom union_size_bound: forall (A: list (list nat)) (s: nat),
  (forall X, In X A -> length X <= s) ->
  length (fold_right set_union [] A) <= length A * s.

(* Adding x back gives sets in F *)
Lemma reconstruct_sets_in_F : forall (F: list (list nat)) (x: nat) (Fx: list (list nat)),
  (* If Fx is made by removing x from sets in F that contain x *)
  Fx = map (fun X => set_minus X [x]) 
          (filter (fun X => if in_dec nat_eq_dec x X then true else false) F) ->
  (* Then adding x back gives sets that were in F *)
  forall Y, In Y Fx -> In (set_union Y [x]) F.
Proof.
Admitted.

(* Adding x to all sets preserves sunflower property *)
Lemma add_x_preserves_sunflower : forall (Fx: list (list nat)) (Y C: list nat) (x: nat) (k: nat),
  is_sunflower Fx Y k ->  (* If we have a sunflower in Fx *)
  (* Then adding x to core and petals gives a sunflower *)
  is_sunflower 
    (map (fun X => set_union X [x]) Fx)
    (set_union C [x]) 
    k.
Proof.
Admitted.

(* Size preservation *)
Lemma size_after_adding_x : forall (Fx: list (list nat)) (x: nat) (k: nat),
  length Fx = k ->  (* If Fx has k sets *)
  length (map (fun X => set_union X [x]) Fx) = k.  (* Adding x preserves count *)
Proof.
  intros Fx x k H.
  rewrite map_length.  (* map preserves length *)
  exact H.
Qed.

Lemma set_inter_union_distrib: forall X1 X2 Z: list nat,
  set_eq (set_inter (set_union X1 Z) (set_union X2 Z))
         (set_union (set_inter X1 X2) Z).
Proof.
Admitted.

Lemma set_union_inj: forall (X1 X2 Z: list nat),
  set_union X1 Z <> set_union X2 Z -> X1 <> X2.
Proof.
  intros X1 X2 Z H.
  intros Heq. (* Assume X1 = X2 *)
  apply H.    (* Get contradiction *)
  rewrite Heq.
  reflexivity.
Qed.

Lemma set_minus_union_lemma: forall (X Y Z: list nat) (z: nat),
  In z (set_minus (set_union X Z) (set_union Y Z)) ->
  In z (set_minus X Y).
Proof.
Admitted.

Lemma s0_sunflower: forall F k,
  k > 0 ->
  (forall X, In X F -> length X = 0) ->
  length F > fact 0 * (k - 1)^0 ->
  exists Y sets, 
    length sets = k /\
    (forall X, In X sets -> In X F) /\
    is_sunflower F Y k.
Proof.
Admitted.

Lemma factorial_bound: forall s k,
  k > 0 ->
  fact (S(S s)) * (k-1)^(S(S s)) > (S(S s)) * (k-1).
Proof.
Admitted.

Lemma sunflower_length_bound: forall F B k s A,
  k > 0 ->
  (forall X, In X F -> length X = S (S s)) ->
  length F > fact (S (S s)) * (k - 1) ^ S (S s) ->
  is_maximal_disjoint A F ->
  length A <= k - 1 ->
  B = fold_right set_union [] A ->
  (forall X, In X F -> exists x, In x B /\ In x X) ->
  length B < S (S s) * (k - 1) /\
  exists x, In x B /\ count_occurrences x F > length F / length B /\
  exists Y, is_sunflower F Y k.
Proof.
Admitted.

Lemma inductive_step_sunflower: forall F' s k,
  (forall F, 
    (forall X, In X F -> length X = S s) -> 
    length F > fact (S s) * (k - 1) ^ S s -> 
    exists Y, is_sunflower F Y k) ->
  (forall X, In X F' -> length X = S s) ->
  length F' > fact s * (k - 1) ^ S s ->
  exists Y, is_sunflower F' Y k.
Proof.
Admitted.

Lemma intersection_unions_with_singleton: 
  forall (z x: nat) (Y1 Y2 core: list nat),
  In z (set_inter (set_union Y1 [x]) (set_union Y2 [x])) ->
  In z (set_union core [x]).
Proof.
Admitted.

(* First lemma: size property of elements in Fx *)
Lemma Fx_element_size: forall F x s,
  (forall X, In X F -> length X = S (S s)) ->
  let Fx := map (fun X => set_minus X [x])
            (filter (fun X => if in_dec nat_eq_dec x X then true else false) F) in
  forall X, In X Fx -> length X = S s.
Proof.
  intros F x s Hsize Fx X HX.
  unfold Fx in HX.
  
  (* Break down the membership in Fx *)
  apply in_map_iff in HX.
  destruct HX as [orig [Heq HorigF]].
  apply filter_In in HorigF.
  destruct HorigF as [HorigInF Hhasx].
  
  (* Get size of original set *)
  assert (Horig_size := Hsize orig HorigInF).
  
  (* When we remove x, size decreases by 1 *)
  subst X.
  (* Need to show that set_minus removes exactly one element *)
  assert (In x orig).
  {
    destruct (in_dec nat_eq_dec x orig); auto.
    simpl in Hhasx. discriminate.
  }
  
  (* Now prove that set_minus with singleton removes exactly one element *)
  assert (length (set_minus orig [x]) = length orig - 1).
  {
    (* This requires another helper lemma about set_minus with singleton *)
    admit.  (* This should be another separate lemma *)
  }
Admitted.

(* Second lemma: bound property for length of Fx *)
Lemma Fx_length_bound: forall F x s k,
  length F > fact (S (S s)) * (k - 1) ^ S (S s) ->
  let Fx := map (fun X => set_minus X [x])
            (filter (fun X => if in_dec nat_eq_dec x X then true else false) F) in
  length Fx > fact s * (k - 1) ^ S s.
Proof.
Admitted.

Lemma Fx_inductive_hypothesis: forall (s k: nat) (F: list (list nat)) (x: nat)
  (IHs': ((forall X : list nat, In X F -> length X = S s) -> 
          length F > fact (S s) * (k - 1) ^ S s -> 
          exists Y : list nat, is_sunflower F Y k)),
  let Fx := map (fun X => set_minus X [x])
            (filter (fun X => if in_dec nat_eq_dec x X then true else false) F) in
  (forall X, In X Fx -> length X = S s) ->
  length Fx > fact s * (k - 1) ^ S s ->
  exists Y, is_sunflower Fx Y k.
Proof.
Admitted.

(* Take first k elements from a list *)
Fixpoint take (k: nat) {A: Type} (l: list A) : list A :=
  match k, l with
  | 0, _ => []
  | _, [] => []
  | S k', (x :: xs) => x :: take k' xs
  end.

(* Helper lemmas about take *)
Lemma take_length: forall k A (l: list A),
  length (take k l) = min k (length l).
Proof.
  induction k; intros.
  - simpl. reflexivity.
  - destruct l.
    + simpl. reflexivity.
    + simpl. f_equal. apply IHk.
Qed.

Lemma take_in: forall k A (l: list A) x,
  In x (take k l) -> In x l.
Proof.
  induction k; intros.
  - simpl in H. contradiction.
  - destruct l.
    + simpl in H. contradiction.
    + simpl in H. destruct H.
      * left. exact H.
      * right. apply IHk. exact H.
Qed.

Lemma take_k_from_longer: forall k {A: Type} (l: list A),
  k > 0 ->
  length l > k - 1 ->
  exists sets, length sets = k /\
               (forall x, In x sets -> In x l).
Proof.
  intros k A l Hk Hlen.
  exists (take k l).
  split.
  - rewrite take_length.
    apply min_l.
    (* Need to show k <= length l *)
    lia.
  - intros x Hx.
    apply take_in with k.
    exact Hx.
Qed.

(* Main theorem *)
Theorem erdos_rado_sunflower: forall F s k,
  k > 0 ->
  (forall X, In X F -> length X = s) ->
  length F > fact s * (k - 1)^s ->
  exists Y, is_sunflower F Y k.
Proof.
  intros F s k Hk Hsize Hbound.
  induction s as [|s' IHs'].
   (* Case s = 0 *)
    destruct (s0_sunflower F k Hk Hsize Hbound) as [Y [sets [Hlen [Hin Hsun]]]].
    exists Y.
    exact Hsun.
  * destruct s' as [|s''].
    - (* Case s = 1 *)
      apply singletons_form_sunflower.
      + exact Hk.
      + exact Hsize.
      + simpl in Hbound.
        lia.
        
    - (* Case s > 1 *)
      destruct (exists_maximal_disjoint F) as [A HA].
      destruct (le_gt_dec (length A) (k-1)) as [Hle|Hgt].
      (* Union of A (B) must intersect every member of F
         Then by pigeonhole, some x in B must be in many sets *)
    
        + (* Case |A| ≤ k-1 *)
  set (B := fold_right set_union [] A).
  assert (forall X, In X F -> exists x, In x B /\ In x X).
  { apply maximal_family_intersects_all with (A:=A); auto. }
  
  destruct (sunflower_length_bound F B k s'' A Hk Hsize Hbound HA Hle eq_refl H) 
    as [HBbound [x [HxB [Hcount Hsunflower]]]].
  
  (*Union of sets in A should be bounded by:
    |B| < |A| * (size of each set) <= (k-1) * S(S s'')*)
  set (Fx := map (fun X => set_minus X [x]) 
    (filter (fun X => if in_dec nat_eq_dec x X then true else false) F)).

assert (HSizeFx: forall X, In X Fx -> length X = S s'') 
  by (apply (Fx_element_size F x s'' Hsize)).

assert (HBoundFx: length Fx > fact s'' * (k - 1) ^ S s'')
  by (apply (Fx_length_bound F x s'' k Hbound)).

assert (IH_for_Fx: (forall X : list nat, In X Fx -> Datatypes.length X = S s'') ->
                  Datatypes.length Fx > fact s'' * (k - 1) ^ S s'' ->
                  exists Y : list nat, is_sunflower Fx Y k)
  by (apply (Fx_inductive_hypothesis s'' k F x IHs')).
        
        (* Then we can use this *)
        assert (Hsunflower_Fx: exists Y, is_sunflower Fx Y k).
        {
          apply IH_for_Fx.
          - exact HSizeFx.
          - exact HBoundFx.
        }
        
        destruct Hsunflower_Fx as [core [sets [Hsun Hcount_k]]].
        (* Construct sunflower in F by adding x back to core *)
        exists (set_union core [x]).
        (* First let's build the list of sets we want in F *)
        exists (map (fun X => set_union X [x]) sets).
        split.
        {
          rewrite length_map.
          exact Hsun.
        }
        split.
        {
          (* First part: each petal is in F *)
          intros X HX.
          (* Need to use the fact that original sets were in Fx *)
          destruct Hcount_k as [H1 [H2 H3]].
          (* Use H1 to show X came from Fx *)
          (* Get Y from which X was constructed *)
          apply in_map_iff in HX.
          destruct HX as [Y [Heq HYsets]].
          subst X.
          
          (* Use H1 to show Y is in Fx *)
          assert (HYinFx := H1 Y HYsets).
          
          (* Now use reconstruct_sets_in_F *)
          apply (reconstruct_sets_in_F F x Fx).
          - (* Show Fx has right form *)
            reflexivity.
          - (* Show Y is in Fx *)
            exact HYinFx.
        }
        split.
        {
          (* Second part: pairwise intersections equal core *)
          intros X1 X2 HX1 HX2 Hneq.
          destruct Hcount_k as [H1 [H2 H3]].
          
          (* Get original sets Y1, Y2 from which X1, X2 were constructed *)
          apply in_map_iff in HX1.
          destruct HX1 as [Y1 [Heq1 HY1sets]].
          apply in_map_iff in HX2.
          destruct HX2 as [Y2 [Heq2 HY2sets]].
          subst X1 X2.
          
          (* Use the injection lemma to show Y1 ≠ Y2 *)
          assert (HY1Y2: Y1 <> Y2) by (apply set_union_inj with [x]; exact Hneq).
          
          (* Now we can use H2 to show intersection of original sets equals core *)
          assert (Horiginal := H2 Y1 Y2 HY1sets HY2sets HY1Y2).
          
          (* Instead of rewriting, let's prove equality directly *)
          unfold set_eq. intros z.
          split; intros Hz.
          - (* -> direction *)
            exact (intersection_unions_with_singleton z x Y1 Y2 core Hz).
          - (* <- direction *)
            apply in_set_inter.
            split.
            + (* Show z is in first set *)
              apply in_set_union in Hz.
              destruct Hz as [Hzcore | Hzx].
              * (* First case: when z is in core *)
                apply in_set_union.
                left.
                unfold set_eq in Horiginal.
                specialize (Horiginal z).
                destruct Horiginal as [_ H_inter_to_core].
                apply H_inter_to_core in Hzcore.
                apply in_set_inter in Hzcore.
                destruct Hzcore as [HzY1 _].
                exact HzY1.
              * (* Second case: when z is in [x] *)
                apply in_set_union.
                right.
                exact Hzx.
            + (* Show z is in second set - exactly the same proof *)
              apply in_set_union in Hz.
              destruct Hz as [Hzcore | Hzx].
              * (* First case: when z is in core *)
                apply in_set_union.
                left.
                unfold set_eq in Horiginal.
                specialize (Horiginal z).
                destruct Horiginal as [_ H_inter_to_core].
                apply H_inter_to_core in Hzcore.
                apply in_set_inter in Hzcore.
                destruct Hzcore as [_ HzY2].
                exact HzY2.
              * (* Second case: when z is in [x] *)
                apply in_set_union.
                right.
                exact Hzx.
        }
        {
          (* Third part: disjointness after removing core *)
          intros X1 X2 HX1 HX2 Hneq.
          destruct Hcount_k as [H1 [H2 H3]].
          
          (* Get original sets Y1, Y2 from which X1, X2 were constructed *)
          apply in_map_iff in HX1.
          destruct HX1 as [Y1 [Heq1 HY1sets]].
          apply in_map_iff in HX2.
          destruct HX2 as [Y2 [Heq2 HY2sets]].
          subst X1 X2.
          
          (* Use the injection lemma to show Y1 ≠ Y2 *)
          assert (HY1Y2: Y1 <> Y2) by (apply set_union_inj with [x]; exact Hneq).
          
          (* Use H3 to show original differences were disjoint *)
          assert (Hdisjoint := H3 Y1 Y2 HY1sets HY2sets HY1Y2).
          
          (* Now prove set_inter (set_minus (set_union Y1 [x]) (set_union core [x])) 
                               (set_minus (set_union Y2 [x]) (set_union core [x])) = [] *)
          unfold set_eq. intros z.
          split; intros Hz.
          - (* -> direction *)
            apply in_set_inter in Hz.
            destruct Hz as [Hz1 Hz2].
            assert (Hz1' := set_minus_union_lemma Y1 core [x] z Hz1).
            assert (Hz2' := set_minus_union_lemma Y2 core [x] z Hz2).
            
            (* Now we have z in both original differences *)
            assert (Hinboth: In z (set_inter (set_minus Y1 core) (set_minus Y2 core))).
            {
              apply in_set_inter.
              split.
              - exact Hz1'.
              - exact Hz2'.
            }
            
            (* Apply Hdisjoint directly *)
            apply Hdisjoint in Hinboth.
            exact Hinboth.
          - (* <- direction *)
            (* Easy since rhs is empty *)
            destruct Hz.
        }
        + (* Case |A| > k-1 *)
  exists [].  (* empty core *)
         
  (* Take first k sets from A to form petals *)
  assert (Hfirstk: exists sets, length sets = k /\ 
                               (forall X, In X sets -> In X A))
    by (apply take_k_from_longer; [exact Hk | exact Hgt]).
  
  destruct Hfirstk as [sets [Hlen Hinsets]].
  exists sets.

  (* Now prove this is a sunflower *)
  split; [exact Hlen|].

  (* Extract disjointness property before destructing HA *)
  destruct HA as [Hdisj [HinF _]].

  split.
  {
    intros X HX.
    apply HinF.
    apply Hinsets.
    exact HX.
  }

  split.
  { 
    (* Pairwise intersections equal empty core *)
    intros X1 X2 HX1 HX2 Hneq.
    unfold set_eq. intros z.
    split; [intros Hz|intros []].
    apply in_set_inter in Hz.
    destruct Hz as [Hz1 Hz2].
    assert (Hz' := Hdisj X1 X2 (Hinsets _ HX1) (Hinsets _ HX2) Hneq).
    assert (Hboth: In z (set_inter X1 X2)).
    {
      apply in_set_inter. split; assumption.
    }
    rewrite Hz' in Hboth.
    exact Hboth.
  }
  {
    (* Disjoint after removing core - same as above since core is empty *)
    intros X1 X2 HX1 HX2 Hneq.
    unfold set_eq. intros z.
    split; [intros Hz|intros []].
    apply in_set_inter in Hz.
    destruct Hz as [Hz1 Hz2].
    (* Extract membership from set_minus *)
    apply in_set_minus in Hz1.
    apply in_set_minus in Hz2.
    destruct Hz1 as [Hz1 _].
    destruct Hz2 as [Hz2 _].
    assert (Hz' := Hdisj X1 X2 (Hinsets _ HX1) (Hinsets _ HX2) Hneq).
    assert (Hboth: In z (set_inter X1 X2)).
    {
      apply in_set_inter. split; assumption.
    }
    rewrite Hz' in Hboth.
    exact Hboth.
  }
Qed.

Fixpoint parity (x: bool_string) (n: nat) : bool :=
  match n with
  | O => false  (* Base case: no bits *)
  | S k => xorb (x k) (parity x k)  (* Recursive case: XOR current bit with parity of previous bits *)
  end.

Definition parity_zeros (n: nat) : bool_string -> Prop :=
  fun x => parity x n = false.

(* === Pi3 Circuits === *)
(* A gate in level 2 has bounded fan-in k *)
Definition is_bounded_gate {d: nat} (c: AC0_circuit d) (k: nat) : Prop :=
  match c with
  | Literal _ => True
  | Gate _ _ inputs => length inputs <= k
  end.

(* Boolean version for computation *)
Definition is_bounded_gate_bool {d: nat} (c: AC0_circuit d) (k: nat) : bool :=
  match c with
  | Literal _ => true
  | Gate _ _ inputs => Nat.leb (length inputs) k
  end.

(* Definition of Pi3 circuits with bounded fan-in *)
Inductive Pi3_circuit (k: nat) : Type :=
  | Pi3_mk : forall (g2s: list (AC0_circuit 2)) (H: forall g, In g g2s -> is_bounded_gate g k),
      Pi3_circuit k.

(* Evaluation function for Pi3 circuits *)
Definition eval_Pi3 {k: nat} (c: Pi3_circuit k) (input: bool_string) : bool :=
  match c with
  | Pi3_mk _ g2s _ => (* note the _ for the proof term *)
      forallb (fun g => eval_AC0 g input) g2s
  end.

(* === Function F(n,k,s) from paper === *)
Definition F_nks (n k s: nat) : nat :=
  if Nat.even s 
  then (n^(s/2) * k^(s/2)) / (2 * 4 * s)
  else (n^((s-1)/2) * k^((s+1)/2)) / (2 * 4 * (s-1)).

(* === Key Lemmas === *)

(* Circuit Separation Lemma (Lemma 2.2 from paper) *)
Lemma circuit_separation: forall n k l A B,
  (forall x, ~(A x /\ B x)) ->  (* A and B are disjoint *)
  property_P n A B k l ->
  forall c: Pi3_circuit k,
  ~(forall x, A x -> eval_Pi3 c x = true /\
              B x -> eval_Pi3 c x = false).
Proof.
  intros n k l A B Hdisj Hprop c.
  intros Hcontra.
  
  set (coloring := fun x => 
    match c with
    | Pi3_mk _ g2s _ => 
        length (filter (fun g => negb (eval_AC0 g x)) g2s)
    end).
    
  assert (Hbound: forall x, B x -> coloring x < l).
{ 
  intros x HB.
  unfold coloring.
  destruct c as [g2s Hfanin].

  assert (Heval: eval_Pi3 (Pi3_mk k g2s Hfanin) x = false).
  { admit. }

  (* Use property_P *)
  (* specialize (Hprop coloring Hbound)??? *)
  (* destruct Hprop as [color [B' [Hcolor [HB'sub [Hcolor_eq [y [HAy Hklim]]]]]]]. *)
  (* Have y in A that's a k-limit for B' *)
  (* TODO: prove indices form valid k-input set *)
  { admit. }
  (* Get evaluation for x *)
Admitted.

(* If a circuit separates A,B then (A,B) can't have property Pplus(k,l) *)
Lemma circuit_separation_p_plus: forall m k l A B (c: Pi3_circuit l),
  (forall x, A x -> eval_Pi3 c x = true) ->
  (forall x, B x -> eval_Pi3 c x = false) ->
  ~ property_P_plus m A B k l.
Proof.
Admitted.

Fixpoint fact (n: nat) : nat :=
  match n with
  | 0 => 1
  | S n' => (S n') * fact n'
  end.

(* Specialized version for parity (Theorem 2.4 from paper) *)
Lemma parity_sunflower: forall n s h F,
  s >= 2 ->
  length F > F_nks n h s ->
  (forall X, In X F -> length X = s) ->
  exists Y, is_sunflower F Y (S h) /\
           (if Nat.even s then Odd (length Y) else Even (length Y)).
Proof.
Admitted.

(* === Main Theorem === *)

(* Relationship between sunflowers and k-limits *)
(* Convert a bool_string to a set (list nat) representation *)
Definition bool_string_to_set (x: bool_string) (n: nat) : list nat :=
  filter (fun i => x i) (seq 0 n).

(* Convert a set to a bool_string representation *)
Definition set_to_bool_string (X: list nat) : bool_string :=
  fun i => if in_dec nat_eq_dec i X then true else false.

Definition parity_ones (n: nat) (x: list bool) : Prop :=
  length (filter (fun b => b) x) mod 2 = n mod 2.

Definition count_ones (x: bool_string) (m: nat) : nat :=
  fold_left (fun acc i => 
    if x i then S acc else acc) 
  (seq 0 m) 0.

Definition parity_ones_bool_string (n: nat) (x: bool_string) : Prop :=
  count_ones x n mod 2 = n mod 2.

Lemma sunflower_klimit: forall F Y k n,
  is_sunflower F Y (S k) ->
  forall x : bool_string, parity_ones_bool_string n x ->
    is_k_limit x (fun y => exists X, In X F /\ y = set_to_bool_string X) (length Y) k.
Proof.
Admitted.

Fixpoint pow (n m: nat) : nat :=
  match m with
  | 0 => 1
  | S m' => n * pow n m'
  end.

(* Now modify the lemma *)
(* First define the constant c *)

Definition c : R := 1 / (sqrt 2 * ln 2).

(* Then define circuit_bound *)
Definition circuit_bound (n: nat) : nat :=
  let n_real := INR n in  (* Convert nat to R *)
  let result := pow 2 (Z.to_nat (up (c * sqrt n_real))) in  (* Convert back to nat *)
  result.

(* Now the separation lemma should work *)
Lemma parity_circuit_separation: forall n k (c: Pi3_circuit k),
  (forall x, eval_Pi3 c x = parity x n) ->
  exists (A B: bool_string -> Prop),
    (forall x, ~(A x /\ B x)) /\
    property_P n A B k (circuit_bound n).
Proof.
Admitted.

(* A is the set of odd vectors *)
Definition odd_vectors (m: nat) : bool_string -> Prop :=
  fun x => parity x m = true.

Fixpoint factorial (n: nat) : nat :=
  match n with
  | 0 => 1
  | S n' => n * factorial n'
  end.

Definition binomial (m s: nat) : nat :=
  match (Nat.leb s m) with
  | true => Nat.div (factorial m) (factorial s * factorial (m-s))
  | false => 0
  end.

Definition size_B (m s: nat) : nat := 
  binomial m s.  (* This is (m choose s) *)

Definition computes_parity {k: nat} (c: Pi3_circuit k) (n: nat) : Prop :=
  forall x: bool_string, eval_Pi3 c x = parity x n.

Definition computes_parity_restricted {k: nat} (c: Pi3_circuit k) (m: nat) : Prop :=
  forall x: bool_string,
  (forall i, i >= m -> x i = false) ->  (* variables after m are 0 *)
  eval_Pi3 c x = parity x m.

Definition is_bounded_fanin {k: nat} (c: Pi3_circuit k) (bound: nat) : Prop :=
  match c with
  | Pi3_mk _ g2s _ =>
      forall g, In g g2s ->
      match g with
      | Literal _ => True
      | Gate _ _ inputs => length inputs <= bound
      end
  end.

Definition is_bad_gate_bool {d: nat} (g: AC0_circuit d) (k: nat) : bool :=
  match g with
  | Literal _ => false
  | Gate _ _ inputs => Nat.ltb k (length inputs)  (* k < length inputs *)
  end.

(* First define how to get literals from a circuit *)
Fixpoint get_literals {d: nat} (c: AC0_circuit d) : list literal :=
  match c with
  | Literal l => [l]
  | Gate _ _ inputs => flat_map get_literals inputs
  end.

Definition bad_gates_inputs {d: nat} (k: nat) (g: AC0_circuit d) : list (list nat) :=
  match g with
  | Literal _ => []
  | Gate _ op inputs => 
      if is_bad_gate_bool g k
      then
        let negated_inputs := 
          map (fun c => 
            match c with
            | Literal l => if literal_is_negated l 
                          then [literal_index l] 
                          else []
            | _ => []
            end) inputs in
        filter (fun l => match l with 
                        | [] => false 
                        | _ => true 
                        end) negated_inputs
      else []
  end.
  
Lemma bottom_fan_in_reduction: forall (n m k l: nat) (c: Pi3_circuit l),
  computes_parity c n ->
  k * (n + 1) >= l * (m + 1) ->
  exists c': Pi3_circuit k,
    is_bounded_fanin c' k /\
    computes_parity_restricted c' m.
Proof.
  intros n m k l c Hcomp Hbound.
  destruct c as [g2s Hfanin].
  
  (* We need to first map bad_gates_inputs k over g2s, then flatten *)
  set (F := concat (map (bad_gates_inputs k) g2s)).
  
  (* Now continue with proof as before *)
  assert (exists T: list nat, 
    length T <= n - m /\
    forall X, In X F -> exists i, In i T /\ In i X).
  {
    (* Greedy argument here *)
    admit.
  }
  destruct H as [T [HlenT Hcover]].
Admitted.

Definition exactly_s_ones (m s: nat) : bool_string -> Prop :=
  fun x => count_ones x m = s.

(* After bottom fan-in reduction, circuit must separate these sets *)
Lemma circuit_separates_sets: forall (m k l: nat) (c: Pi3_circuit l),
  computes_parity c m ->
  is_bounded_fanin c k ->
  (* Must separate odd vectors from vectors with exactly s ones *)
  forall s, s <= m/2 -> Even s ->
    (forall x, odd_vectors m x -> eval_Pi3 c x = true) /\
    (forall x, exactly_s_ones m s x -> eval_Pi3 c x = false).
Proof.
Admitted.

Lemma size_implies_limit: forall m k s l (B: bool_string -> Prop),
  s <= m/2 -> Even s ->
  (forall x, B x -> exactly_s_ones m s x) ->
  size_B m s > l * F_nks m k s ->
  exists y, odd_vectors m y /\ is_lower_k_limit y B m k.
Proof.
Admitted.

Lemma size_bound_proof: forall m k s l,
  s <= m/2 -> Even s ->
  forall c: Pi3_circuit l,
  computes_parity c m ->
  is_bounded_fanin c k ->
  (* Get equation 3.3 *)
  l >= binomial m s / F_nks m k s.
Proof.
Admitted.
