(*  Title:         WpSoundness.thy
    Authors:       Xueying Qin, U Edinburgh; Liam O'Connor, U Edinburgh; Peter Hoefner, ANU
    Contributions: Ohad Kammar, U Edinburgh; Rob van Glabbeek, U Edinburgh; Michel Steuwer, U Edinburgh
    Maintainer:    Xueying Qin <xueying.qin@ed.ac.uk>
*)

section \<open>Weakest Precondition is Sound w.r.t. the Denotational Semantics\<close>

theory WpSoundness
  imports  Denotational MonoDenotational Wp
begin

subsection \<open>Theorems about update\<close>

theorem UpdateWithLookupUnchanged:
  assumes "e \<in> defined l"
  shows "update l e {E (lookup l e)} = {E e}"
  using assms
proof (induct l arbitrary: e )
  case empty 
  thus ?case by fastforce
next
  case (Lcons pos loc) 
  thus ?case
    by(cases pos; fastforce simp: Lcons)
qed

theorem UpdateErrGivesErr: 
  assumes "e \<in> defined l"
  shows "update l e {Err} = {Err}"
  using assms
proof (induct l arbitrary: e)
  case empty 
  thus ?case by simp
next
  case (Lcons pos loc) 
  thus ?case
    by(cases pos; fastforce simp: Lcons)
qed

lemma update_inter_err_div: 
  assumes "e \<in> defined l"
  shows "update l e es \<inter> {Err, Div} = es \<inter> {Err, Div}" 
  using assms 
proof (induction l arbitrary: e es)
  case empty
  thus ?case by simp
next
  case (Lcons pos loc)
  thus ?case   
    by(cases pos; fastforce simp: Lcons)
qed

lemma defined_append : 
  "x \<in> defined (loc \<triangleright> pos) \<Longrightarrow> x \<in> defined loc"
proof (induct loc arbitrary: x)
  case empty
  thus ?case 
    by simp
next
  case (Lcons pos loc)
  thus ?case     
    by(cases pos; fastforce simp: Lcons)
qed

lemma lookup_id_append_undefined: 
  "\<lbrakk>x \<in> defined loc ; lookup loc x = exp.Leaf xa\<rbrakk> \<Longrightarrow> x \<notin> defined (loc\<triangleright>p)"
proof (induct loc arbitrary: x)
  case empty
  thus ?case 
    using defined.elims by auto[1]
next
  case (Lcons pos loc)
  thus ?case
    by(cases pos; fastforce simp: Lcons)
qed

lemma append_undefined_lookup_id: 
  "\<lbrakk>x \<in> defined loc ; x \<notin> defined (loc\<triangleright>p)\<rbrakk> \<Longrightarrow> \<exists>n. lookup loc x = Leaf n"
proof (induct loc arbitrary: x)
  case empty
  thus ?case 
    apply (cases x,simp)
    by(cases p, simp_all)
next
  case (Lcons pos loc)
  thus ?case 
    by(cases pos; fastforce)
qed

subsection \<open>The @{text "lookup_exec_update"} function\<close>
definition lookup_exec_update :: "strategy \<Rightarrow> location \<Rightarrow> exp \<Rightarrow> env \<Rightarrow> exp_err_div set"
  where "lookup_exec_update s loc e senv = (update loc e (PdToSet (exec s senv (lookup loc e))))"

text
 \<open> The following simp rules mean that (for defined locations), you shouldn't usually need to use 
   @{text "lookup_exec_update_def"}. Instead, these rules give an alternative definitionn. For 
   @{text "lookup_exec_update"} that doesn't refer to other functions like update, lookup etc. at 
   all \<close>

lemma lookup_exec_update_simp1[simp] : 
  "lookup_exec_update s \<epsilon> e senv = PdToSet (exec s senv e)" 
  by (simp add: lookup_exec_update_def)

lemma lookup_exec_update_simp2[simp] : 
  assumes "e1 \<in> defined loc"
  shows "lookup_exec_update s (Left\<triangleleft>loc) (Node l e1 e2) senv 
       = {E (Node l x e2) | x. E x \<in> lookup_exec_update s loc e1 senv} 
         \<union> (lookup_exec_update s loc e1 senv \<inter> {Err, Div})" 
  using assms 
  by (force simp: lookup_exec_update_def update_inter_err_div)

lemma lookup_exec_update_simp3[simp] : 
  assumes "e2 \<in> defined loc"
  shows "lookup_exec_update s (Right\<triangleleft>loc) (Node l e1 e2) senv 
       = {E (Node l e1 x) | x. E x \<in> lookup_exec_update s loc e2 senv} 
         \<union> (lookup_exec_update s loc e2 senv \<inter> {Err, Div})" 
  using assms 
  by (force simp: lookup_exec_update_def update_inter_err_div)

text
 \<open> If @{text "l"} is defined in an expression, updating that expression with 
   @{text "lookup_exec_update"} will maintain the definedness of @{text "l"}. \<close>
theorem lookup_exec_update_defined:
  assumes "e \<in> defined l"
  shows "\<forall> x. E x \<in> lookup_exec_update s l e senv \<longrightarrow> x \<in> defined l"
  using assms 
proof (induction l arbitrary: e)
  case empty
  thus ?case 
    by simp
next
  case (Lcons pos l)
  thus ?case 
    by(cases pos; fastforce intro!: Lcons)
qed

lemma lookup_exec_update_nonempty:
  assumes "x \<in> defined loc"
  shows   "\<exists>r. r \<in> lookup_exec_update s loc x senv" 
  using assms 
proof (induct loc arbitrary: x)
  case empty
  thus ?case 
    using Rep_powerdomain[simplified] by fastforce
next
  case (Lcons pos loc)
  thus ?case
  proof(cases x)
    case Leaf
    thus ?thesis 
      using Lcons.prems 
      by (fastforce simp: lookup_exec_update_def
                    dest: UpdateErrGivesErr)
  next
    case Node
    thus ?thesis 
      apply (cases pos)
      using  Lcons exp_err_div.exhaust by (clarsimp, metis)+
    qed
qed

subsection \<open>Order independence lemmas\<close>
text \<open> A collection of lemmas about defined and @{text "lookup_exec_update"} that are useful for 
   reordering  executions, in e.g. the soundness proofs of all \<close>
lemma defined_left_right : 
  "x \<in> defined (loc \<triangleright> Left) \<Longrightarrow> x \<in> defined (loc \<triangleright> Right)"
proof (induct loc arbitrary: x)
  case empty
  thus ?case by simp
next
  case (Lcons pos loc)
  thus ?case 
    by(cases pos, fastforce+)
qed

lemma defined_right_left : 
  "x \<in> defined (loc \<triangleright> Right) \<Longrightarrow> x \<in> defined (loc \<triangleright> Left)"
proof (induct loc arbitrary: x)
  case empty
  thus ?case by simp
next
  case (Lcons pos loc)
  thus ?case 
    by (cases pos; fastforce+)
qed

lemma defined_right_after_left: 
  assumes "E x2 \<in> lookup_exec_update s (loc\<triangleright>Left) x1 senv"
  shows   "x1 \<in> defined (loc \<triangleright> Right) \<Longrightarrow> x2 \<in> defined (loc\<triangleright>Right)" 
  by (fastforce intro: assms 
                dest:  defined_left_right defined_right_left lookup_exec_update_defined)

lemma defined_left_after_right:
  assumes "E x2 \<in> lookup_exec_update s (loc\<triangleright>Right) x1 senv"
  shows   "x1 \<in> defined (loc \<triangleright> Left) \<Longrightarrow> x2 \<in> defined (loc\<triangleright>Left)"
  by (fastforce intro: assms 
                dest:  defined_left_right defined_right_left lookup_exec_update_defined)

lemma lookup_exec_update_left_right_swap : 
  assumes "x1 \<in> defined (loc \<triangleright> Left)"
    and   "x1 \<in> defined (loc \<triangleright> Right)"
  shows   "(\<exists>i. E i \<in> lookup_exec_update s1 (loc \<triangleright> Left) x1 senv \<and> E x2 \<in> lookup_exec_update s2 (loc \<triangleright> Right) i senv)
       \<longleftrightarrow> (\<exists>j. E j \<in> lookup_exec_update s2 (loc \<triangleright> Right) x1 senv \<and> E x2 \<in> lookup_exec_update s1 (loc \<triangleright> Left) j senv)"
  using assms
proof (induct loc arbitrary: x1 x2)
  case empty
  thus ?case 
    by fastforce
next
  case (Lcons pos loc)
  thus ?case
    by (cases pos; fastforce intro: Lcons simp: defined_left_after_right defined_right_after_left)
qed

lemma err_right_after_left: 
  assumes "E x2 \<in> lookup_exec_update s (loc\<triangleright>Left) x1 senv"
    and   "x1 \<in> defined (loc \<triangleright> Left)" 
  shows   "Err \<in> lookup_exec_update s (loc\<triangleright>Right) x1 senv \<longleftrightarrow> Err \<in> lookup_exec_update s (loc\<triangleright>Right) x2 senv"
  using assms 
proof (induct loc arbitrary: x1 x2)
  case empty
  thus ?case 
    by fastforce
next
  case (Lcons pos loc)
  thus ?case 
    by (cases pos; fastforce dest: lookup_exec_update_defined simp: defined_left_right)
qed

lemma err_left_after_right: 
  assumes "E x2 \<in> lookup_exec_update s (loc\<triangleright>Right) x1 senv" 
    and   "x1 \<in> defined (loc \<triangleright> Right)" 
  shows   "Err \<in> lookup_exec_update s (loc\<triangleright>Left) x1 senv \<longleftrightarrow> Err \<in> lookup_exec_update s (loc\<triangleright>Left) x2 senv"
  using assms 
proof (induct loc arbitrary: x1 x2)
  case empty
  thus ?case 
    by fastforce
next
  case (Lcons pos loc)
  thus ?case 
    by (cases pos; fastforce dest: lookup_exec_update_defined simp: defined_right_left)
qed

lemma div_right_after_left: 
  assumes "E x2 \<in> lookup_exec_update s (loc\<triangleright>Left) x1 senv"
    and   "x1 \<in> defined (loc \<triangleright> Left)"
  shows   "Div \<in> lookup_exec_update s (loc\<triangleright>Right) x1 senv \<longleftrightarrow> Div \<in> lookup_exec_update s (loc\<triangleright>Right) x2 senv"
  using assms 
proof (induct loc arbitrary: x1 x2)
  case empty
  thus ?case 
    by fastforce 
next
  case (Lcons pos loc)
  thus ?case 
    by (cases pos; fastforce dest: lookup_exec_update_defined simp: defined_left_right)
qed

lemma div_left_after_right: 
  assumes "E x2 \<in> lookup_exec_update s (loc\<triangleright>Right) x1 senv" 
    and   "x1 \<in> defined (loc \<triangleright> Right)" 
  shows   "Div \<in> lookup_exec_update s (loc\<triangleright>Left) x1 senv 
           \<longleftrightarrow> Div \<in> lookup_exec_update s (loc\<triangleright>Left) x2 senv"
  using assms 
proof (induct loc arbitrary: x1 x2)
  case empty
  thus ?case 
    by fastforce
next
  case (Lcons pos loc)
  thus ?case 
    by (cases pos; fastforce dest: lookup_exec_update_defined simp: defined_right_left)+
qed

subsection \<open>@{text "wp_sound_set"} and @{text "wp_err_sound_set"}\<close> 

text 
 \<open> These definitions are an aid to help us to formulate our inductive hypotheses.
   They are the semantic meaning of wp. \<close>
definition wp_sound_set :: "strategy \<Rightarrow> location \<Rightarrow> exp set \<Rightarrow> env \<Rightarrow> exp set"
  where "wp_sound_set s loc P senv = 
          {e | e. e \<in> defined loc \<and> lookup_exec_update s loc e senv \<subseteq> E ` P}"

definition wp_err_sound_set :: "strategy \<Rightarrow> location \<Rightarrow> exp set \<Rightarrow> env \<Rightarrow> exp set"
  where "wp_err_sound_set s loc P senv = 
          {e | e. e \<in> defined loc \<and>  lookup_exec_update s loc e senv \<subseteq> E ` P \<union> {Err}}"

subsection \<open>Sequential Composition Lemmas\<close>

(* Helper to avoid having to do lots of SetToPd (PdToSet ..) reasoning *)
lemma PdToSet_seq : "PdToSet ((s1 ;;s s2) e)
                   =  (\<Union>{PdToSet (s2 x) | x. E x \<in> PdToSet (s1 e)}
                            \<union> {x | x. x \<in> PdToSet (s1 e) \<inter> {Div, Err}})"
  apply (simp add: seq_s_def)
  apply (subst Abs_powerdomain_inverse; simp)
  by (metis (mono_tags, lifting)  Rep_powerdomain ex_in_conv exp_err_div.exhaust mem_Collect_eq)

(* lookup_exec_update of sequential composition is sequential composition of lookup_exec_update *)
lemma lookup_exec_update_seq: 
  assumes "e \<in> defined loc"
  shows "lookup_exec_update (s1;; s2) loc e senv
       = (\<Union> {lookup_exec_update s2 loc x senv | x. E x \<in> lookup_exec_update s1 loc e senv} 
           \<union> {x | x. x \<in> lookup_exec_update s1 loc e senv \<inter> {Div, Err}})"
  using assms 
proof (induction loc arbitrary: e)
  case empty
  thus ?case 
    by (fastforce simp: lookup_exec_update_def PdToSet_seq)
next
  case (Lcons pos loc)
  thus ?case
    by(cases pos; fastforce simp: Lcons lookup_exec_update_defined) (* takes some time *)
qed


lemma seq_wp_sound_set_cases:
  assumes "x \<in> defined loc"
  and     "lookup_exec_update (s1;; s2) loc x senv \<subseteq> E ` P"
  and     "xa \<in> lookup_exec_update s1 loc x senv"
shows     "xa \<in> E ` {uu \<in> defined loc. lookup_exec_update s2 loc uu senv \<subseteq> E ` P}" 
  using assms apply clarsimp
  apply (frule lookup_exec_update_seq[where ?s1.0 = s1 and ?s2.0 = s2])
    apply (cases xa)
      apply blast
    by (fastforce simp: lookup_exec_update_defined)+

(* wp_sound_set rule for sequential_composition  (mirrors the wp rule) *)
lemma seq_wp_sound_set: 
  "wp_sound_set (s1 ;; s2) loc P senv = wp_sound_set s1 loc (wp_sound_set s2 loc P senv) senv"
  by (fastforce simp: lookup_exec_update_seq wp_sound_set_def seq_wp_sound_set_cases)

(* wp_err_sound_set rule for sequential_composition  (mirrors the wp_err rule) *)
lemma seq_wp_err_sound_set: 
  "wp_err_sound_set (s1 ;; s2) loc P senv = wp_err_sound_set s1 loc (wp_err_sound_set s2 loc P senv) senv"
  (is "?lhs = ?rhs")
proof 
  show "?lhs \<subseteq> ?rhs"
    unfolding wp_err_sound_set_def apply clarsimp
    apply (frule lookup_exec_update_seq[where ?s1.0 = s1 and ?s2.0 = s2 and senv = senv], clarsimp)
    by (fastforce simp: lookup_exec_update_defined 
                 intro:  exp_err_div_intros
                 split:  exp_err_div.splits)
next
  show "?rhs \<subseteq> ?lhs"
    unfolding wp_err_sound_set_def
    by (fastforce simp: lookup_exec_update_seq wp_err_sound_set_def)
qed

subsection \<open>Left Choice Lemmas\<close>
(* Helper for PdToSet of left choice *)
lemma PdToSet_lc: 
  "PdToSet ((s <+s t) e) = (PdToSet (s e) - {Err})  \<union> {x | x. x \<in> PdToSet (t e) \<and> Err \<in> PdToSet (s e)}"
  unfolding lchoice_s_def
  by (metis Abs_powerdomain_inverse[simplified] Rep_powerdomain[simplified] subset_singleton_iff 
            ex_in_conv singletonI Diff_eq_empty_iff mem_Collect_eq sup_eq_bot_iff)

(* lookup_exec_update of left choice is the left choice of lookup_exec_update *)
lemma lookup_exec_update_lc: 
  assumes "e \<in> defined loc" 
  shows "lookup_exec_update (s1 <+ s2) loc e senv = 
         (lookup_exec_update s1 loc e senv - {Err}) 
           \<union> {x | x. x \<in> lookup_exec_update s2 loc e senv \<and> Err \<in> lookup_exec_update s1 loc e senv}"
  using assms 
proof (induction loc arbitrary: e)
  case empty
  thus ?case 
    by (fastforce simp: PdToSet_lc)
next
  case (Lcons pos loc)
  thus ?case 
    by (cases pos; fastforce)
qed

(* wp_sound_set rule for left choice (simplified wp rule) *)
lemma lc_wp_sound_set: 
  "wp_sound_set (s1 <+ s2) loc P senv = 
      wp_sound_set s1 loc P senv \<union> (wp_err_sound_set s1 loc P senv \<inter> wp_sound_set s2 loc P senv)"
  by (fastforce simp: lookup_exec_update_lc wp_sound_set_def wp_err_sound_set_def)

(* wp_err_sound_set rule for left choice (simplified wp_err rule) *)
lemma lc_wp_err_sound_set: 
  "wp_err_sound_set (s1 <+ s2) loc P senv = 
     wp_sound_set s1 loc P senv \<union> (wp_err_sound_set s1 loc P senv \<inter> wp_err_sound_set s2 loc P senv)"
  unfolding wp_sound_set_def wp_err_sound_set_def apply clarsimp
  by (fastforce simp: lookup_exec_update_lc intro: exp_err_div_intros split: exp_err_div.splits)

subsection \<open>Choice Lemmas\<close>
  (* Helper for PdToSet of choice *)
lemma PdToSet_choice : "PdToSet ((s1 ><s s2) e) = {E x | x. E x \<in> PdToSet (s1 e)}
                                  \<union> {d. d = Div \<and> Div \<in> PdToSet (s1 e)}
                                  \<union> {E y | y. E y \<in> PdToSet (s2 e)}
                                  \<union> {d. d = Div \<and> Div \<in> PdToSet (s2 e)}
                                  \<union> {err. err = Err \<and> Err \<in> PdToSet (s1 e) \<inter> PdToSet (s2 e)}"
  unfolding choice_s_def
  using Rep_powerdomain
  apply (subst Abs_powerdomain_inverse; clarsimp)
   by (metis (mono_tags, lifting) ex_in_conv exp_err_div.exhaust)

(* lc_wp_sound_set[simplified wp_sound_set_def wp_err_sound_set_def lookup_exec_update_def, simplified] .
seq_wp_sound_set[simplified wp_sound_set_def lookup_exec_update_def, simplified]

*)
(* lookup_exec_update of choice is the choice of lookup_exec_update, 
   this is the simplified choice semantics *)
lemma lookup_exec_update_choice: 
  assumes "e \<in> defined loc" 
  shows "lookup_exec_update (s1 >< s2) loc e senv = 
          {E x | x. E x \<in> lookup_exec_update s1 loc e senv}
          \<union> {d. d = Div \<and> Div \<in> lookup_exec_update s1 loc e senv}
          \<union> {E y | y. E y \<in> lookup_exec_update s2 loc e senv}
          \<union> {d. d = Div \<and> Div \<in> lookup_exec_update s2 loc e senv}
          \<union> {err. err = Err \<and> Err \<in> lookup_exec_update s1 loc e senv \<inter> lookup_exec_update s2 loc e senv}"
  using assms 
proof (induction loc arbitrary: e)
  case empty
  thus ?case 
    by (simp add: PdToSet_choice)
next
  case (Lcons pos loc)
  thus ?case (* Rather slow*)
    by (cases pos; fastforce)
qed

(* wp_sound_set rule for choice (simplified wp rule) *)
lemma choice_wp_sound_set: 
  "wp_sound_set (s1 >< s2) loc P senv = 
        (wp_sound_set s1 loc P senv \<inter> wp_err_sound_set s2 loc P senv) 
      \<union> (wp_err_sound_set s1 loc P senv \<inter> wp_sound_set s2 loc P senv)"
   unfolding wp_sound_set_def wp_err_sound_set_def 
  by (fastforce simp: lookup_exec_update_choice
                intro: exp_err_div_intros 
                split: exp_err_div.splits)

(* wp_err_sound_set rule for choice (simplified wp rule) *)
lemma choice_wp_err_sound_set: 
  "wp_err_sound_set (s1 >< s2) loc P senv = 
   wp_err_sound_set s1 loc P senv \<inter> wp_err_sound_set s2 loc P senv"
  apply (rule antisym)
   unfolding wp_sound_set_def wp_err_sound_set_def
   by (fastforce simp: lookup_exec_update_choice
                intro: exp_err_div_intros 
                split: exp_err_div.splits)+
 
subsection \<open>One Lemmas\<close>
lemma PdToSet_one: 
  "PdToSet ((one_s s) e) = 
        {E (Node l x e2) | l x e1 e2. e = Node l e1 e2 \<and> E x \<in> PdToSet (s e1)}
      \<union> {d | l e1 e2 d. e = Node l e1 e2 \<and> d = Div \<and> Div \<in> PdToSet (s e1)}
      \<union> {E (Node l e1 x) | l x e1 e2. e = Node l e1 e2 \<and> E x \<in> PdToSet (s e2)}
      \<union> {d | l e1 e2 d. e = Node l e1 e2 \<and> d = Div \<and> Div \<in> PdToSet (s e2)}
                   \<union> {err | e1 e2 l err. err = Err \<and> (e = Leaf l \<or> (e = Node l e1 e2 \<and> Err \<in> PdToSet (s e1) \<inter> PdToSet (s e2)))}"
  unfolding one_s_def
  apply (subst Abs_powerdomain_inverse; simp)
  apply (cases e; simp)
  by (metis (mono_tags, lifting) Rep_powerdomain ex_in_conv exp_err_div.exhaust mem_Collect_eq)

lemma lookup_exec_update_one:
  assumes "e \<in> defined loc" 
  shows  "lookup_exec_update (one s) loc e senv 
                                  = {E x | x. e \<in> defined (loc \<triangleright> Left) \<and> E x \<in> lookup_exec_update s (loc \<triangleright> Left) e senv}
                                  \<union> {d. d = Div \<and> e \<in> defined (loc \<triangleright> Left) \<and> Div \<in> lookup_exec_update s (loc \<triangleright> Left) e senv}
                                  \<union> {E y | y. e \<in> defined (loc \<triangleright> Right) \<and>  E y \<in> lookup_exec_update s (loc \<triangleright> Right) e senv}
                                  \<union> {d. d = Div \<and> e \<in> defined (loc \<triangleright> Right) \<and> Div \<in> lookup_exec_update s (loc \<triangleright> Right) e senv}
                                  \<union> {err. err = Err \<and> (e \<in> defined (loc \<triangleright> Left) 
                                                  \<longrightarrow>  e \<in> defined (loc \<triangleright> Right) 
                                                  \<longrightarrow> Err \<in> lookup_exec_update s (loc \<triangleright> Left) e senv \<inter> lookup_exec_update s (loc \<triangleright> Right) e senv)}"
  using assms 
proof (induct loc arbitrary: e)
  case empty
  thus ?case
    apply (cases e)
     by (force simp: PdToSet_one)+
next
  case (Lcons pos loc)
  thus ?case 
    by (cases pos; fastforce simp: Lcons)
qed

lemma lookup_exec_update_one_elem:
  "e \<in> defined loc
   \<Longrightarrow> var \<in> lookup_exec_update (one s) loc e senv =
       (case var of
          Err \<Rightarrow> (e \<in> defined (loc \<triangleright> Left) \<and> e \<in> defined (loc \<triangleright> Right) 
                  \<longrightarrow> Err \<in> lookup_exec_update s (loc \<triangleright> Left) e senv
                          \<inter> lookup_exec_update s (loc \<triangleright> Right) e senv)
        | Div \<Rightarrow> (e \<in> defined (loc \<triangleright> Left) \<and> Div \<in> lookup_exec_update s (loc \<triangleright> Left) e senv) \<or>
                 (e \<in> defined (loc \<triangleright> Right) \<and> Div \<in> lookup_exec_update s (loc \<triangleright> Right) e senv)
        | E x \<Rightarrow> (e \<in> defined (loc \<triangleright> Left) \<and> E x \<in> lookup_exec_update s (loc \<triangleright> Left) e senv) \<or>
                 (e \<in> defined (loc \<triangleright> Right) \<and>  E x \<in> lookup_exec_update s (loc \<triangleright> Right) e senv))"
proof (induct loc arbitrary: var e)
  case empty
  thus ?case
    apply(cases e)
    by (fastforce simp: PdToSet_one split: exp_err_div.splits)+
next
  case (Lcons pos loc)
  thus ?case 
    by (cases pos; fastforce simp: Lcons split: exp_err_div.splits)
qed

(* wp_sound_set rule for one (simplified wp rule) *)
lemma one_wp_sound_set: "wp_sound_set (one s) loc P senv 
                      = (wp_err_sound_set s (loc \<triangleright> Left) P senv \<inter> wp_sound_set s (loc \<triangleright> Right) P senv)
                      \<union> (wp_sound_set s (loc \<triangleright> Left) P senv \<inter> wp_err_sound_set s (loc \<triangleright> Right) P senv)"
  (is "?lhs = ?rhs")
proof (rule subset_antisym)
  show "?lhs \<subseteq> ?rhs"
    unfolding wp_sound_set_def wp_err_sound_set_def 
    (* takes a few seconds *)
    by (fastforce simp: lookup_exec_update_one
                 intro: exp_err_div_intros 
                 split: exp_err_div.splits)
  show "?rhs \<subseteq> ?lhs"
   unfolding wp_sound_set_def wp_err_sound_set_def
   (* takes some seconds *)
   by (fastforce simp: defined_append lookup_exec_update_one
               intro: exp_err_div_intros 
               split: exp_err_div.splits)
qed

(* wp_err_sound_set rule for one (simplified wp rule) *)
lemma one_wp_err_sound_set: 
  "wp_err_sound_set (one s) loc P senv = 
        {e | e x. e \<in> defined loc \<and> lookup loc e = Leaf x}
      \<union> wp_err_sound_set s (loc \<triangleright> Left) P senv \<inter> wp_err_sound_set s (loc \<triangleright> Right) P senv"
  (is "?lhs = ?rhs1 \<union> ?rhs2")
proof (rule antisym)
  show "?lhs \<subseteq> ?rhs1 \<union> ?rhs2"
    unfolding wp_err_sound_set_def
    by (fastforce simp: append_undefined_lookup_id lookup_exec_update_one_elem
                 split: exp_err_div.splits)
next
  show "?rhs1 \<union> ?rhs2 \<subseteq> ?lhs" 
    unfolding wp_err_sound_set_def
    by (fastforce dest: defined_append
                  simp: lookup_id_append_undefined lookup_exec_update_one_elem
                 split: exp_err_div.splits)
qed

subsection \<open>All Lemmas\<close>
lemma PdToSet_all:
  "PdToSet ((all_s s) e) = {E (Node l x1 x2) | l x1 x2 e1 e2. e = Node l e1 e2 \<and> E x1 \<in> PdToSet (s e1) \<and> E x2 \<in> PdToSet (s e2)}
                   \<union> {E (Leaf l) | l. e = Leaf l }
                   \<union> {d | l e1 e2 d. (e = Node l e1 e2 \<and> d = Div \<and> Div \<in> PdToSet (s e1) \<union> PdToSet (s e2)) }
                   \<union> {err | e1 e2 l err. err = Err \<and> (e = Node l e1 e2 \<and> Err \<in> PdToSet (s e1) \<union> PdToSet (s e2))}"
  unfolding all_s_def
  apply (subst Abs_powerdomain_inverse, simp)
  by (metis Rep_powerdomain[simplified] equals0I exp_err_div.exhaust exp.exhaust)+

lemma lookup_exec_update_all:
  assumes "e \<in> defined loc" 
  shows  "lookup_exec_update (all s) loc e senv 
                                    = {E y | x y. e \<in> defined (loc \<triangleright> Left) \<and> x \<in> defined (loc \<triangleright> Right) \<and> E x \<in> lookup_exec_update s (loc \<triangleright> Left) e senv
                                            \<and> E y \<in> lookup_exec_update s (loc \<triangleright> Right) x senv}
                                      \<union> {E e | l. lookup loc e = Leaf l}
                                      \<union> {d. d = Div \<and> e \<in> defined (loc \<triangleright> Left) \<and> Div \<in> lookup_exec_update s (loc \<triangleright> Left) e senv}
                                      \<union> {d. d = Div \<and> e \<in> defined (loc \<triangleright> Right) \<and> Div \<in> lookup_exec_update s (loc \<triangleright> Right) e senv}
                                      \<union> {err. err = Err \<and> e \<in> defined (loc \<triangleright> Left) \<and> Err \<in> lookup_exec_update s (loc \<triangleright> Left) e senv}
                                      \<union> {err. err = Err \<and> e \<in> defined (loc \<triangleright> Right) \<and> Err \<in> lookup_exec_update s (loc \<triangleright> Right) e senv}"
  using assms 
proof (induct loc arbitrary: e)
  case empty
  thus ?case 
    apply (simp add: PdToSet_all)
    apply (rule subset_antisym)
     apply (rule subsetI)
     apply simp
      (* getting try to solve this requires us to break it down first *)
     apply (elim disjE conjE exE; force)
    by (fastforce split: exp.splits)
next
  case (Lcons pos loc)
  thus ?case
  proof (cases pos)
    case Left
    thus ?thesis
      using Lcons.hyps Lcons.prems apply clarsimp
      apply (rule set_eqI, clarsimp)
      apply (rule iffI)
       by (elim disjE conjE exE; clarsimp | fastforce | force)+
  next
    case Right
    thus ?thesis
      using Lcons.hyps Lcons.prems apply clarsimp
      apply (rule set_eqI, clarsimp)
      apply (rule iffI)
       by (elim disjE conjE exE; clarsimp | fastforce | force)+
   qed 
 qed

(* wp_sound_set rule for all (simplified wp rule) *)
lemma all_wp_sound_set: "wp_sound_set (all s) loc P senv = (P \<inter> {e | e x. e \<in> defined loc \<and> lookup loc e = Leaf x})
                          \<union> wp_sound_set s (loc \<triangleright> Left) (wp_sound_set s (loc \<triangleright> Right) P senv) senv
                          \<union> wp_sound_set s (loc \<triangleright> Right) (wp_sound_set s (loc \<triangleright> Left) P senv) senv"
( is "?lhs = ?rhs1 \<union> ?rhs2 \<union> ?rhs3")

proof(rule subset_antisym)
  show "?lhs \<subseteq> ?rhs1 \<union> ?rhs2 \<union> ?rhs3"
(* part I *)
    unfolding  wp_sound_set_def apply clarsimp
   apply (simp add: lookup_exec_update_all)
   apply clarsimp
   apply (rule conjI)
  using append_undefined_lookup_id apply (smt (verit, ccfv_threshold) Collect_mono_iff Setcompr_eq_image exp_err_div.inject)
   apply clarsimp
  apply (rename_tac xa)
   apply (case_tac xa)
     apply clarsimp
  using append_undefined_lookup_id apply (smt (verit, ccfv_threshold) Collect_mem_eq Collect_mono_iff exp_err_div.distinct(1) exp_err_div.inject image_iff)
    apply clarsimp
   apply (rule imageI)
    apply (case_tac "x \<notin> defined (loc\<triangleright>Right)")
     apply clarsimp
     apply (rule conjI)
  using append_undefined_lookup_id
  apply force
  using append_undefined_lookup_id apply force
   apply simp                    
   apply (rule conjI)
  using defined_right_after_left
  apply(fastforce simp: defined_right_after_left)
  apply (smt (z3) defined_right_after_left defined_right_left div_right_after_left err_right_after_left exp_err_div.exhaust mem_Collect_eq subset_iff)
  using append_undefined_lookup_id 
  apply (smt (verit, del_insts) exp_err_div.inject exp_err_div.simps(7) imageE mem_Collect_eq subsetD)
(* end part I *)
  done

  show "(?rhs1) \<union> ?rhs2 \<union> ?rhs3 \<subseteq> ?lhs"
  proof- 
    have rhs1: "?rhs1 \<subseteq> ?lhs"
      unfolding  wp_sound_set_def
      by (fastforce simp: lookup_id_append_undefined lookup_exec_update_all)

    have rhs2: "?rhs2 \<subseteq> ?lhs"
      unfolding  wp_sound_set_def apply clarsimp
      apply (frule  defined_append)
      using lookup_exec_update_nonempty
      by (fastforce simp: lookup_exec_update_all err_right_after_left div_right_after_left 
                          lookup_id_append_undefined)
    have rhs3: "?rhs3 \<subseteq> ?lhs"
      unfolding  wp_sound_set_def apply clarsimp
      apply (frule  defined_append)
      using lookup_exec_update_nonempty lookup_exec_update_left_right_swap
      by (fastforce simp: lookup_exec_update_all err_left_after_right div_left_after_right 
                          lookup_id_append_undefined)
  from rhs1 rhs2 rhs3
  show ?thesis
    by blast
qed
qed

(* wp_err_sound_set rule for all (simplified wp rule) *)
lemma all_wp_err_sound_set: "wp_err_sound_set (all s) loc P senv 
                      = (P \<inter> {e | e x. e \<in> defined loc \<and> lookup loc e = Leaf x})
                        \<union> (wp_err_sound_set s (loc \<triangleright> Left) (wp_err_sound_set s (loc \<triangleright> Right) P senv) senv
                        \<inter> wp_err_sound_set s (loc \<triangleright> Right) (wp_err_sound_set s (loc \<triangleright> Left) P senv) senv)"
(is "?lhs = ?rhs1 \<union> ?rhs2")
proof(rule antisym)
  show "?lhs \<subseteq> ?rhs1\<union>?rhs2"
(*  proof -
    fix x
    have "x\<in>?lhs \<Longrightarrow> x\<notin>?rhs1 \<Longrightarrow> x\<in>?rhs2"*)
  unfolding wp_err_sound_set_def
   apply (rule subsetI)
  apply simp
   apply (rename_tac x)
   apply (case_tac "x \<notin> defined (loc\<triangleright>pos.Left)")
     apply(fastforce simp: lookup_exec_update_all append_undefined_lookup_id) 
   apply (rule disjI2)
   apply (erule conjE)
   apply (simp add: lookup_exec_update_all)
   apply (clarsimp)
   apply (intro conjI)
     apply (rule subsetI)
    apply (rename_tac xa)
     apply (frule defined_left_right)
     apply (case_tac xa)
       apply fastforce
      apply simp
      apply (rule imageI)
      apply clarsimp
      apply (rename_tac x1)
      apply (frule lookup_exec_update_defined[rule_format], simp)
      apply (rule conjI)
       apply (fastforce simp: defined_left_right)
      apply (rule subsetI)
      apply (rename_tac xb)
      apply (case_tac xb)
        apply fastforce
       apply (drule_tac c = xb in subsetD)
  using defined_left_right  apply meson
  apply force
       apply (force simp:)
       apply (force simp: defined_left_right div_right_after_left)
       apply (fastforce simp: defined_left_right div_right_after_left)
       apply (fastforce simp: defined_left_right div_right_after_left)
   apply (rule subsetI)
  apply (rename_tac xa)
(* 1 *)
   apply (case_tac xa)
     apply fastforce
    apply clarsimp
    apply (rule imageI)
    apply clarsimp
  using  lookup_exec_update_defined   apply (meson imageI defined_left_after_right)
    apply (rule subsetI)
   apply (rename_tac xb)
(* 2 *)
    apply (case_tac xb)
      apply fastforce
(*3 *)

   apply (frule lookup_exec_update_left_right_swap[THEN iffD2]) (* 5 *)
      apply(metis defined_left_right) 
      apply( fastforce simp: defined_left_right) 
(*3*)
    apply (metis (mono_tags, lifting) defined_left_right Un_iff mem_Collect_eq subset_Un_eq)
(* 2 *)
  apply (force simp: defined_right_after_left defined_left_right div_left_after_right)
  apply (force simp: defined_right_after_left defined_left_right div_left_after_right) (* some seconds *)
  done
  show "?rhs1 \<union> ?rhs2 \<subseteq> ?lhs"
    unfolding  wp_err_sound_set_def
    by (fastforce simp: lookup_id_append_undefined lookup_exec_update_all dest: defined_append)
  qed

subsection \<open>Some Lemmas\<close>
lemma PdToSet_some: 
  "PdToSet ((some_s s) e) = {E (Node l x1 x2) | l x1 x2 e1 e2. e = Node l e1 e2 \<and> E x1 \<in> PdToSet (s e1) \<and> E x2 \<in> PdToSet (s e2)}
                    \<union> {E (Node l x e2) | l x e1 e2. e = Node l e1 e2 \<and> E x \<in> PdToSet (s e1) \<and> Err \<in> PdToSet (s e2)} 
                    \<union> {E (Node l e1 x) | l x e1 e2. e = Node l e1 e2 \<and> E x \<in> PdToSet (s e2) \<and> Err \<in> PdToSet (s e1)}
                    \<union> {d | l e1 e2 d. (e = Node l e1 e2 \<and> d = Div \<and> Div \<in> PdToSet (s e1) \<union> PdToSet (s e2))}
                    \<union> {err | e1 e2 l err. err = Err \<and> (e = Leaf l \<or> (e = Node l e1 e2 \<and> Err \<in> PdToSet (s e1) \<inter> PdToSet (s e2)))}"
  unfolding some_s_def
  apply (subst Abs_powerdomain_inverse)
   apply (cases e, simp_all)
  by (metis Rep_powerdomain[simplified] equals0I exp_err_div.exhaust)

declare[[show_types, show_sorts]]

lemma lookup_exec_update_some:
  assumes "e \<in> defined loc" 
  shows  "lookup_exec_update (some s) loc e senv 
                                  = {E x | x. e \<in> defined (loc \<triangleright> Left) \<inter> defined (loc \<triangleright> Right) 
                                            \<and> E x \<in> lookup_exec_update s (loc \<triangleright> Left) e senv \<and> Err \<in> lookup_exec_update s (loc \<triangleright> Right) e senv}
                                  \<union> {d. d = Div \<and> e \<in> defined (loc \<triangleright> Left) \<and> Div \<in> lookup_exec_update s (loc \<triangleright> Left) e senv}
                                  \<union> {E y | y. e \<in> defined (loc \<triangleright> Left) \<inter> defined (loc \<triangleright> Right) 
                                            \<and> E y \<in> lookup_exec_update s (loc \<triangleright> Right) e senv \<and> Err \<in> lookup_exec_update s (loc \<triangleright> Left) e senv}
                                  \<union> {d. d = Div \<and> e \<in> defined (loc \<triangleright> Right) \<and> Div \<in> lookup_exec_update s (loc \<triangleright> Right) e senv}
                                  \<union> {E z | x z. e \<in> defined (loc \<triangleright> Left) \<inter> defined (loc \<triangleright> Right) \<and> E x \<in> lookup_exec_update s (loc \<triangleright> Left) e senv
                                            \<and> E z \<in> lookup_exec_update s (loc \<triangleright> Right) x senv}
                                  \<union> {err. err = Err \<and> (e \<in> defined (loc \<triangleright> Left) 
                                                  \<longrightarrow>  e \<in> defined (loc \<triangleright> Right) 
                                                  \<longrightarrow> Err \<in> lookup_exec_update s (loc \<triangleright> Left) e senv \<inter> lookup_exec_update s (loc \<triangleright> Right) e senv)}"
  using assms
proof (induct loc arbitrary: e)
  case empty
  thus ?case
    apply (simp add: PdToSet_some)
    apply (cases e)
     apply force
    apply (rule subset_antisym)
     apply (rule subsetI; simp)
     apply (elim disjE conjE exE; force)
    by force
  next
  case (Lcons pos loc)
  thus ?case
    apply (cases pos)
     apply (rule set_eqI, clarsimp)
     apply (rule iffI)
      apply (elim disjE conjE exE; force simp: defined_right_after_left)
     apply (elim disjE conjE exE; force simp: defined_right_after_left)
    apply (rule set_eqI, clarsimp)
    apply (rule iffI)
     apply (elim disjE conjE exE; force simp: defined_right_after_left)
    by (elim disjE conjE exE; force simp: defined_right_after_left)
  qed

(* wp_sound_set rule for some (simplified wp rule) *)
lemma some_wp_sound_set: "wp_sound_set (some s) loc P senv 
                      = wp_sound_set s (loc \<triangleright> Left) (wp_sound_set s (loc \<triangleright> Right) P senv) senv
                           \<union> wp_sound_set s (loc \<triangleright> Right) (wp_sound_set s (loc \<triangleright> Left) P senv) senv 
                           \<union> (wp_sound_set s (loc \<triangleright> Left) P senv \<inter> wp_sound_set s (loc \<triangleright> Left) (wp_err_sound_set s (loc \<triangleright> Right) P senv) senv)
                           \<union> (wp_sound_set s (loc \<triangleright> Right) P senv \<inter> wp_sound_set s (loc \<triangleright> Right) (wp_err_sound_set s (loc \<triangleright> Left) P senv) senv)"
  (is "?lhs = ?rhs")

proof (rule antisym)
  show "?lhs \<subseteq> ?rhs"
  proof 
    fix x::exp
    show "x \<in> ?lhs \<Longrightarrow> x \<in> ?rhs"
    proof (cases "x \<in> defined (loc\<triangleright>pos.Right)")
      show "x \<in> defined (loc\<triangleright>pos.Right) \<Longrightarrow> x \<in> ?lhs \<Longrightarrow>  x \<in> ?rhs"
        apply (simp add: wp_sound_set_def wp_err_sound_set_def lookup_exec_update_some)      
        apply (cases "Err \<in> lookup_exec_update s (loc\<triangleright>pos.Left) x senv")
        using lookup_exec_update_left_right_swap defined_right_left
         apply (fastforce intro!: disjI2 exp_err_div_intros
                          simp: lookup_exec_update_some div_left_after_right defined_left_after_right
                          split: exp_err_div.splits)
        apply (cases "Err \<in> lookup_exec_update s (loc\<triangleright>pos.Right) x senv")
         apply (rule disjI2)
         apply (rule disjI2)
         apply(fastforce intro!: disjI1 exp_err_div_intros 
                         simp: lookup_exec_update_some div_right_after_left defined_right_after_left 
                        split: exp_err_div.splits)
        by (fastforce intro!: disjI1 exp_err_div_intros
                      simp: lookup_exec_update_some defined_right_after_left div_right_after_left err_right_after_left
                      split: exp_err_div.splits)
      show "x \<notin> defined (loc\<triangleright>pos.Right) \<Longrightarrow> x \<in> ?lhs \<Longrightarrow> x \<in> ?rhs"
        by (fastforce simp: wp_sound_set_def lookup_exec_update_some) 
    qed 
  qed
  show "?rhs \<subseteq> ?lhs"  
  proof 
    fix x::exp
    show "x \<in> ?rhs \<Longrightarrow> x \<in> ?lhs"
    proof (cases "x \<in> defined loc")
      show "x \<in> defined loc \<Longrightarrow> x \<in> ?rhs \<Longrightarrow>  x \<in> ?lhs"
        unfolding wp_sound_set_def wp_err_sound_set_def apply simp
        apply (elim disjE; simp add: lookup_exec_update_some)
           using lookup_exec_update_nonempty 
           apply (fastforce simp: defined_left_right div_right_after_left err_right_after_left)
          apply (intro conjI)
                  apply (fastforce)
                 using lookup_exec_update_nonempty apply (fastforce simp: div_left_after_right)
                apply (fastforce simp: err_left_after_right)
               apply (fastforce)
              using lookup_exec_update_left_right_swap apply (fastforce)
             apply (fastforce simp: defined_right_left)
            using lookup_exec_update_nonempty
           apply (fastforce simp: lookup_exec_update_some defined_left_right div_right_after_left) (* takes a few seconds *)
          apply (intro conjI)
             apply blast
            using lookup_exec_update_nonempty 
            apply (fastforce simp: div_left_after_right intro: defined_right_left)
           apply blast
          apply blast
         using lookup_exec_update_left_right_swap apply (fastforce)
        by (fastforce simp: defined_right_left)
    show "x \<notin> defined loc \<Longrightarrow> x \<in> ?rhs \<Longrightarrow>  x \<in> ?lhs"
      unfolding wp_sound_set_def
      by (fastforce intro: defined_append)
    qed
  qed
qed


(* wp_err_sound_set rule for some (simplified wp rule) *)
lemma some_wp_err_sound_set: "wp_err_sound_set (some s) loc P senv 
                      = {e | e x. e \<in> defined loc \<and> lookup loc e = Leaf x}
                        \<union> (wp_err_sound_set s (loc \<triangleright> Left) (wp_err_sound_set s (loc \<triangleright> Right) P senv) senv
                           \<inter> wp_err_sound_set s (loc \<triangleright> Right) (wp_err_sound_set s (loc \<triangleright> Left) P senv) senv
                           \<inter> (wp_err_sound_set s (loc \<triangleright> Left) P senv \<union> wp_err_sound_set s (loc \<triangleright> Left) (wp_sound_set s (loc \<triangleright> Right) P senv) senv)
                           \<inter> (wp_err_sound_set s (loc \<triangleright> Right) P senv \<union> wp_err_sound_set s (loc \<triangleright> Right) (wp_sound_set s (loc \<triangleright> Left) P senv) senv))"
  (is "?lhs = ?rhs")
proof (rule antisym)
  show "?lhs \<subseteq> ?rhs"
  apply (simp add: wp_sound_set_def wp_err_sound_set_def)
   apply (rule subsetI)
   apply (rename_tac x)
   apply simp
   apply (erule conjE)
   apply (simp add: lookup_exec_update_some)
   apply simp
   apply (elim conjE exE)
   apply (case_tac "x \<in> defined (loc\<triangleright>pos.Left)")
    apply (frule defined_left_right)
    apply simp
    apply (rule disjI2)
    apply (case_tac "Err \<in> lookup_exec_update s (loc\<triangleright>pos.Left) x senv")
     apply (case_tac "Err \<in> lookup_exec_update s (loc\<triangleright>pos.Right) x senv")
      apply simp
      apply (intro conjI)
         apply (rule subsetI)
         apply (rename_tac xa)
         apply (case_tac xa)
           apply blast
          apply clarsimp
          apply (rule imageI)
          apply simp
          apply (rule conjI)
  using defined_right_after_left apply simp
          apply (rule subsetI)
          apply (rename_tac xa)
          apply (case_tac xa)
            apply blast
           apply fast
  using div_right_after_left apply simp
         apply blast
        apply (rule subsetI)
        apply (rename_tac xa)
        apply (case_tac xa)
          apply blast
         apply clarsimp
         apply (rule imageI)
         apply simp
         apply (rule conjI)
  using defined_left_after_right apply simp
         apply (rule subsetI)
         apply (rename_tac xa)
         apply (case_tac xa)
           apply blast
  using lookup_exec_update_left_right_swap apply fast
  using div_left_after_right apply simp
        apply auto[1]
       apply (rule disjI1)
       apply (rule subsetI)
       apply (rename_tac xa)
       apply (case_tac xa)
         apply blast
        apply blast
       apply blast
      apply (rule disjI1)
      apply (rule subsetI)
      apply (rename_tac xa)
      apply (case_tac xa)
        apply blast
       apply blast
      apply blast
     apply simp
     apply (intro conjI)
        apply (rule subsetI)
        apply (rename_tac xa)
        apply (case_tac xa)
          apply blast
         apply clarsimp
         apply (rule imageI)
         apply simp
         apply (rule conjI)
  using defined_right_after_left apply auto[1]
         apply (rule subsetI)
         apply (rename_tac xa)
         apply (case_tac xa)
           apply blast
          apply fast
  using div_right_after_left apply simp
        apply blast
       apply (rule subsetI)
       apply (rename_tac xa)
       apply (case_tac xa)
         apply blast
        apply clarsimp
        apply (rule imageI)
        apply simp
        apply (rule conjI)
  using defined_left_after_right apply simp
        apply (rule subsetI)
        apply (rename_tac xa)
        apply (case_tac xa)
          apply blast
  using lookup_exec_update_left_right_swap apply fast
  using div_left_after_right apply simp
       apply auto[1]
      apply (rule disjI2)
      apply (rule subsetI)
      apply (rename_tac xa)
      apply (case_tac xa)
        apply blast
       apply clarsimp
       apply (rule imageI)
       apply simp
       apply (rule conjI)
  using defined_right_after_left apply auto[1]
       apply (rule subsetI)
       apply (rename_tac xa)
       apply (case_tac xa)
  using err_right_after_left apply simp
        apply fast
  using div_right_after_left apply auto[1]
      apply blast
     apply (rule disjI1)
     apply (rule subsetI)
     apply (rename_tac xa)
     apply (case_tac xa)
       apply blast
      apply auto[1]
     apply blast
    apply (case_tac "Err \<in> lookup_exec_update s (loc\<triangleright>pos.Right) x senv")
     apply simp
     apply (intro conjI)
        apply (rule subsetI)
        apply (rename_tac xa)
        apply (case_tac xa)
          apply blast
         apply clarsimp
         apply (rule imageI)
         apply simp
         apply (rule conjI)
  using defined_right_after_left apply simp
         apply (rule subsetI)
         apply (rename_tac xa)
         apply (case_tac xa)
           apply blast
          apply fast
  using div_right_after_left apply auto[1]
        apply blast
       apply (rule subsetI)
       apply (rename_tac xa)
       apply (case_tac xa)
         apply blast
        apply clarsimp
        apply (rule imageI)
        apply simp
        apply (rule conjI)
  using defined_left_after_right apply auto[1]
        apply (rule subsetI)
        apply (rename_tac xa)
        apply (case_tac xa)
          apply blast
  using lookup_exec_update_left_right_swap apply fast
  using div_left_after_right apply simp
       apply auto[1]
      apply (rule disjI1)
      apply (rule subsetI)
      apply (rename_tac xa)
      apply (case_tac xa)
        apply blast
       apply blast
      apply blast
     apply (rule disjI2)
     apply (rule subsetI)
     apply (rename_tac xa)
     apply (case_tac xa)
       apply blast
      apply clarsimp
      apply (rule imageI)
      apply simp
      apply (rule conjI)
  using defined_left_after_right apply auto[1]
      apply (rule subsetI)
      apply (rename_tac xa)
      apply (case_tac xa)
  using err_left_after_right apply simp
  using lookup_exec_update_left_right_swap apply fast
  using div_left_after_right apply simp
     apply auto[1]
    apply simp
    apply (intro conjI)
       apply (rule subsetI)
       apply (rename_tac xa)
       apply (case_tac xa)
         apply blast
        apply clarsimp
        apply (rule imageI)
        apply simp
        apply (rule conjI)
  using defined_right_after_left apply auto[1]
        apply (rule subsetI)
        apply (rename_tac xa)
        apply (case_tac xa)
          apply blast
         apply fast
  using div_right_after_left apply simp
       apply blast
      apply (rule subsetI)
      apply (rename_tac xa)
      apply (case_tac xa)
        apply blast
       apply clarsimp
       apply (rule imageI)
       apply simp
       apply (rule conjI)
  using defined_left_after_right apply auto[1]
       apply (rule subsetI)
       apply (rename_tac xa)
       apply (case_tac xa)
         apply blast
  using lookup_exec_update_left_right_swap apply fast
  using div_left_after_right apply simp
      apply blast
     apply (rule disjI2)
     apply (rule subsetI)
    apply (rename_tac xa)
(* 3 *)
     apply (case_tac xa)
       apply blast
      apply clarsimp
      apply (rule imageI)
     apply simp
(* 4 *)
      apply (rule conjI)
  using defined_right_after_left apply simp
  apply (fastforce simp: err_right_after_left div_right_after_left intro: exp_err_div_intros split: exp_err_div.split)
(* 3 *)

    apply blast
(* 2 *)
  using lookup_exec_update_left_right_swap
  apply (fastforce intro!: disjI2 simp: defined_left_after_right div_left_after_right err_left_after_right intro: exp_err_div_intros split: exp_err_div.split)
   apply simp
  using append_undefined_lookup_id apply fastforce
  done
  show "?rhs \<subseteq> ?lhs"
  proof 
    fix x
    show "x \<in> ?rhs \<Longrightarrow> x \<in> ?lhs"
    proof (cases "x \<in> defined loc")
      show "x \<in> defined loc \<Longrightarrow> x \<in> ?rhs \<Longrightarrow> x \<in> ?lhs"
        apply (simp add: wp_sound_set_def wp_err_sound_set_def lookup_exec_update_some)
        apply (erule disjE)
         using lookup_id_append_undefined apply fastforce
         apply (elim conjE disjE)
         by (fastforce intro: defined_append simp: err_right_after_left err_left_after_right)+
      show "x \<notin> defined loc \<Longrightarrow> x \<in> ?rhs \<Longrightarrow> x \<in> ?lhs"
        unfolding wp_err_sound_set_def
        by(fastforce intro: defined_append)
    qed
  qed
qed



subsection \<open>Mu lemmas\<close>

lemma update_big_union_equals_big_union_update:
  assumes "x \<in> defined loc"
  shows
    "update loc x (\<Union>xa\<in>A. PdToSet (snd xa (lookup loc x))) = (\<Union>xa\<in>A. update loc x (PdToSet (snd xa (lookup loc x))))"
  using assms 
proof (induct loc arbitrary: x)
  case empty
  thus ?case 
    by simp
next
  case (Lcons pos loc)
  thus ?case
    by (cases pos; fastforce)
qed

lemma wp_mu_admissible : "ccpo.admissible Sup (\<le>)
        (\<lambda>x. Rep_pt (fst (fst x) loc) P = {e \<in> defined loc. update loc e (PdToSet (snd x (lookup loc e))) \<subseteq> E ` P})"
  apply (rule ccpo.admissibleI)
  apply (simp add : fst_Sup snd_Sup Sup_pt)
  apply (subst Abs_pt_inverse)
   apply simp
   apply (intro mono_intros)
  apply (rule set_eqI)
  apply simp
  apply (rename_tac A x)
  apply (case_tac "\<forall> elem \<in> (\<lambda> xa. xa (lookup loc x)) ` (snd ` A). Div \<in> PdToSet elem")
   apply (frule div_Sup_ub[rotated 2])
     apply clarsimp
    apply simp
    apply (frule chain_snd_exist)
    apply (metis (mono_tags, lifting) chain_imageI le_fun_def)
   apply simp
   apply (subst Abs_powerdomain_inverse)
    apply simp
    apply blast
   apply (rule iffI)
    apply clarsimp
    apply (rotate_tac 3)
    apply (rename_tac a b c)
    apply (drule_tac x = "((a, b), c)" in bspec)
     apply simp
    apply simp
  using update_inter_err_div apply blast
   apply clarsimp
   apply (simp add: update_big_union_equals_big_union_update)
   apply blast
  apply clarsimp
  apply (rename_tac a b c)
  apply (frule_tac A="(\<lambda> xa. xa (lookup loc x)) ` (snd ` A)" in no_div_Sup_ub[rotated 2])
    apply clarsimp
    apply (frule chain_snd_exist)
    apply (metis (mono_tags, lifting) chain_imageI le_fun_def)
   apply clarsimp
   apply (rule imageI)
  using image_iff apply fastforce
  apply clarsimp
  apply (rule iffI)
   apply clarsimp
   apply (rename_tac a1 b1 c1)
   apply (subgoal_tac "c (lookup loc x) = c1 (lookup loc x)")
    apply simp
    apply blast
   apply (rule antisym)
    apply (rule_tac A="(\<lambda> xa. xa (lookup loc x)) ` (snd ` A)" in no_div_collapses)
       apply clarsimp
       apply (frule chain_snd_exist)
       apply (metis (mono_tags, lifting) chain_imageI le_fun_def)
      apply (rule imageI)
      apply simp
  using image_eqI apply (metis (no_types, opaque_lifting) snd_conv)
     apply (rule imageI)
     apply simp
  using image_eqI apply (metis (no_types, opaque_lifting) snd_conv)
    apply clarsimp
  using update_inter_err_div apply blast
   apply (rule_tac A="(\<lambda> xa. xa (lookup loc x)) ` (snd ` A)" in no_div_collapses)
      apply clarsimp
      apply (frule chain_snd_exist)
      apply (metis (mono_tags, lifting) chain_imageI le_fun_def)
     apply (rule imageI)
     apply simp
  using image_eqI apply (metis (no_types, opaque_lifting) snd_conv)
    apply (rule imageI)
    apply simp
  using image_eqI apply (metis (no_types, opaque_lifting) snd_conv)
   apply clarsimp
  apply clarsimp
  apply (frule chain_snd_exist)
  by fastforce

lemma wp_err_mu_admissible : "ccpo.admissible Sup (\<le>)
        (\<lambda>x. Rep_pt (snd (fst x) loc) P = {e \<in> defined loc. update loc e (PdToSet (snd x (lookup loc e))) \<subseteq> E ` P \<union> {Err}})"
  apply (rule ccpo.admissibleI)
  apply (simp add : fst_Sup snd_Sup Sup_pt)
  apply (subst Abs_pt_inverse)
   apply simp
   apply (intro mono_intros)
  apply (rule set_eqI)
  apply simp
  apply (rename_tac A x)
  apply (case_tac "\<forall> elem \<in> (\<lambda> xa. xa (lookup loc x)) ` (snd ` A). Div \<in> PdToSet elem")
   apply (frule div_Sup_ub[rotated 2])
     apply clarsimp
    apply simp
    apply (frule chain_snd_exist)
    apply (metis (mono_tags, lifting) chain_imageI le_fun_def)
   apply simp
   apply (subst Abs_powerdomain_inverse)
    apply simp
    apply blast
   apply (rule iffI)
    apply clarsimp
    apply (rotate_tac 3)
    apply (rename_tac a b c)
    apply (drule_tac x = "((a, b), c)" in bspec)
     apply simp
    apply simp
  using update_inter_err_div apply blast
   apply clarsimp
   apply (simp add: update_big_union_equals_big_union_update)
   apply blast
  apply clarsimp
  apply (frule_tac A="(\<lambda> xa. xa (lookup loc x)) ` (snd ` A)" in no_div_Sup_ub[rotated 2])
    apply clarsimp
    apply (frule chain_snd_exist)
    apply (metis (mono_tags, lifting) chain_imageI le_fun_def)
   apply clarsimp
   apply (rule imageI)
  using image_iff apply fastforce
  apply clarsimp
  apply (rename_tac a b c)
  apply (rule iffI)
   apply clarsimp
   apply (rename_tac a1 b1 c1)
   apply (subgoal_tac "c (lookup loc x) = c1 (lookup loc x)")
    apply simp
    apply blast
   apply (rule antisym)
    apply (rule_tac A="(\<lambda> xa. xa (lookup loc x)) ` (snd ` A)" in no_div_collapses)
       apply clarsimp
       apply (frule chain_snd_exist)
       apply (metis (mono_tags, lifting) chain_imageI le_fun_def)
      apply (rule imageI)
      apply simp
  using image_eqI apply (metis (no_types, opaque_lifting) snd_conv)
     apply (rule imageI)
     apply simp
  using image_eqI apply (metis (no_types, opaque_lifting) snd_conv)
    apply clarsimp
  using update_inter_err_div apply blast
   apply (rule_tac A="(\<lambda> xa. xa (lookup loc x)) ` (snd ` A)" in no_div_collapses)
      apply clarsimp
      apply (frule chain_snd_exist)
      apply (metis (mono_tags, lifting) chain_imageI le_fun_def)
     apply (rule imageI)
     apply simp
  using image_eqI apply (metis (no_types, opaque_lifting) snd_conv)
    apply (rule imageI)
    apply simp
  using image_eqI apply (metis (no_types, opaque_lifting) snd_conv)
   apply clarsimp
  apply clarsimp
  apply (frule chain_snd_exist)
  by fastforce


subsection \<open>Soundness theorem\<close>

theorem wp_wp_err_soundness: 
  assumes "\<forall> X l P. (Rep_pt (env (X, Tot) l) P) 
                    = {e | e. e \<in> (defined l) \<and> (update l e (PdToSet ((senv X) (lookup l e)))) \<subseteq> E ` P}
            \<and> (Rep_pt (env (X, Par) l) P) 
                = {e | e. e \<in> (defined l) \<and> (update l e (PdToSet ((senv X) (lookup l e)))) \<subseteq> E ` P \<union> {Err}}"
  shows "(wp s loc P env) 
          = {e | e. e \<in> (defined loc) \<and> (update loc e (PdToSet (exec s senv (lookup loc e)))) \<subseteq> E ` P}"
    "(wp_err s loc P env)
          = {e | e. e \<in> (defined loc) \<and> (update loc e (PdToSet (exec s senv (lookup loc e)))) \<subseteq> E ` P \<union> {Err}}"
  using assms
proof (induct s arbitrary: P loc env senv)
  case SKIP case 1 thus ?case
    by (fastforce simp: UpdateWithLookupUnchanged)
next
  case SKIP case 2 thus ?case
    by (fastforce simp: UpdateWithLookupUnchanged)
next
  case ABORT case 1 thus ?case
    by (fastforce simp: UpdateErrGivesErr)
next
  case ABORT case 2 thus ?case
    by (fastforce simp: UpdateErrGivesErr)
next
  case Atomic case 1 thus ?case
    by (fastforce)
next 
  case Atomic case 2 thus ?case
    by (fastforce)
next
  case (Seq s1 s2) note hyps=this {
    case 1 thus ?case
      apply clarsimp
      apply (subst hyps(1), fastforce)
      apply (subst hyps(3), fastforce)
      by (subst seq_wp_sound_set_point, fastforce)
  next 
    case 2 thus ?case
      apply clarsimp
      apply (subst hyps(2), fastforce)
      apply (subst hyps(4), fastforce)
      by (simp add: seq_wp_err_sound_set[simplified wp_err_sound_set_def lookup_exec_update_def, simplified])
  }
next
  case (Left_Choice s1 s2) note hyps=this {
    case 1 thus ?case 
      apply clarsimp
      apply (subst hyps(1), fastforce)
      apply (subst hyps(2), fastforce)
      apply (subst hyps(3), fastforce)
      apply (simp add: lc_wp_sound_set_point)
      by simp
  next
    case 2 thus ?case 
      apply clarsimp
      apply (subst hyps(1)[where senv=senv], simp)
      apply (subst hyps(2)[where senv=senv], simp)
      apply (subst hyps(4)[where senv=senv], simp)
      apply (subst lc_wp_err_sound_set[simplified wp_sound_set_def wp_err_sound_set_def lookup_exec_update_def, simplified, 
            where loc=loc and ?s1.0=s1 and senv=senv and ?s2.0=s2 and P=P])
      by simp
  }
next
  case (Choice s1 s2) note hyps=this {
    case 1 thus ?case
      apply clarsimp
      apply (subst hyps(1)[where senv=senv], simp)
      apply (subst hyps(2)[where senv=senv], simp)
      apply (subst hyps(3)[where senv=senv], simp)
      apply (subst hyps(4)[where senv=senv], simp)
      apply (subst choice_wp_sound_set[simplified wp_sound_set_def wp_err_sound_set_def lookup_exec_update_def, simplified, 
            where loc=loc and ?s1.0=s1 and senv=senv and ?s2.0=s2 and P=P])
      by auto
    case 2 thus ?case
      apply clarsimp
      apply (subst hyps(2)[where senv=senv], simp)
      apply (subst hyps(4)[where senv=senv], simp)
      apply (subst choice_wp_err_sound_set[simplified wp_sound_set_def wp_err_sound_set_def lookup_exec_update_def, simplified,
            where loc=loc and ?s1.0=s1 and senv=senv and ?s2.0=s2 and P=P])
      by auto
  }
next 
  case (One s) note hyps=this {
    case 1 thus ?case
      apply clarsimp
      apply (subst hyps(1)[where senv=senv], simp)
      apply (subst hyps(2)[where senv=senv], simp)
      apply (subst hyps(1)[where senv=senv], simp)
      apply (subst hyps(2)[where senv=senv], simp)
      apply (subst one_wp_sound_set[simplified wp_sound_set_def wp_err_sound_set_def lookup_exec_update_def, simplified,
            where loc=loc and ?s=s and senv=senv  and P=P])
      by auto
  next
    case 2 thus ?case
      apply clarsimp
      apply (subst hyps(2)[where senv=senv], simp)
      apply (subst hyps(2)[where senv=senv], simp)
      apply (subst one_wp_err_sound_set[simplified wp_sound_set_def wp_err_sound_set_def lookup_exec_update_def, simplified,
            where loc=loc and ?s=s and senv=senv  and P=P])
      by auto
  }
next
  case (All s) note hyps=this {
    case 1 thus ?case
      apply clarsimp
      apply (subst hyps(1)[where senv=senv], simp)
      apply (subst hyps(1)[where senv=senv], simp)
      apply (subst hyps(1)[where senv=senv], simp)
      apply (subst hyps(1)[where senv=senv], simp)
      apply (subst all_wp_sound_set[simplified wp_sound_set_def wp_err_sound_set_def lookup_exec_update_def, simplified,
            where loc=loc and ?s=s and senv=senv  and P=P])
      by auto
  next
    case 2 thus ?case
      apply clarsimp
      apply (subst hyps(2)[where senv=senv], simp)
      apply (subst hyps(2)[where senv=senv], simp)
      apply (subst hyps(2)[where senv=senv], simp)
      apply (subst hyps(2)[where senv=senv], simp)
      apply (subst all_wp_err_sound_set[simplified wp_sound_set_def wp_err_sound_set_def lookup_exec_update_def, simplified,
            where loc=loc and ?s=s and senv=senv  and P=P])
      by auto
  }

next
  case (CSome s) note hyps=this {
    case 1 thus ?case
      apply clarsimp
      unfolding  wp_sound_set_def wp_err_sound_set_def lookup_exec_update_def
      using CSome.hyps some_wp_sound_set wp_sound_set_def wp_err_sound_set_def lookup_exec_update_def
      sledgehammer
      apply (subst hyps(2)[where senv=senv], simp)
      apply (subst hyps(1)[where senv=senv], simp)
      apply (subst hyps(1)[where senv=senv], simp)
      apply (subst hyps(2)[where senv=senv], simp)
      apply (subst hyps(1)[where senv=senv], simp)
      apply (subst hyps(1)[where senv=senv], simp)
      apply (subst hyps(1)[where senv=senv], simp)
      apply (subst hyps(1)[where senv=senv], simp)
      apply (subst hyps(1)[where senv=senv], simp)
      apply (subst hyps(1)[where senv=senv], simp)
      apply (subst some_wp_sound_set[simplified wp_sound_set_def wp_err_sound_set_def lookup_exec_update_def, simplified,
            where loc=loc and ?s=s and senv=senv  and P=P])
      by simp
  next
    case 2 thus ?case
      apply clarsimp
      apply (subst hyps(2)[where senv=senv], simp)
      apply (subst hyps(2)[where senv=senv], simp)
      apply (subst hyps(2)[where senv=senv], simp)
      apply (subst hyps(2)[where senv=senv], simp)
      apply (subst hyps(2)[where senv=senv], simp)
      apply (subst hyps(2)[where senv=senv], simp)
      apply (subst hyps(2)[where senv=senv], simp)
      apply (subst hyps(2)[where senv=senv], simp)
      apply (subst hyps(1)[where senv=senv], simp)
      apply (subst hyps(1)[where senv=senv], simp)
      apply (subst some_wp_err_sound_set[simplified wp_sound_set_def wp_err_sound_set_def lookup_exec_update_def, simplified,
            where loc=loc and ?s=s and senv=senv  and P=P])
      by simp
  }

next
  case FixVar case 1 thus ?case
    by simp
next
  case FixVar case 2 thus ?case
    by simp
next 
  case (Mu v s) note hyps=this {
    case 1 thus ?case
      apply (subgoal_tac 
          "\<forall> P loc. 
                (wp (mu v. s) loc P env = {e |e. e \<in> defined loc \<and> update loc e (PdToSet (exec (mu v. s) senv (lookup loc e))) \<subseteq> E ` P})
                \<and> (wp_err (mu v. s) loc P env = {e |e. e \<in> defined loc \<and> update loc e (PdToSet (exec (mu v. s) senv (lookup loc e))) \<subseteq> E ` P \<union> {Err}})")
       apply simp
      apply simp
      apply (rule parallel_fixp_induct[where f="\<lambda> x. (\<lambda>loc. Abs_pt (\<lambda>P. wp s loc P (env((v, Tot) := fst x, (v, Par) := snd x))),
                  \<lambda>loc. Abs_pt (\<lambda>P. wp_err s loc P (env((v, Tot) := fst x, (v, Par) := snd x))))"and g="\<lambda> x. exec s (senv(v := x))"])
          apply (rule admissible_all)
          apply (rule admissible_all)
          apply (rule admissible_conj)
           apply (rule wp_mu_admissible)
          apply (rule wp_err_mu_admissible[simplified])
         apply (simp add: fst_Sup snd_Sup Sup_pt pd_Sup)
         apply (subst Abs_pt_inverse)
          apply simp
          apply (intro mono_intros)
         apply (subst Abs_pt_inverse)
          apply simp
          apply (intro mono_intros)
         apply clarsimp
      using update_inter_err_div apply blast
        apply (intro mono_intros)
       apply (rule monoI)
       apply (rule exec_mono)
       apply simp
      apply clarsimp
      apply (subst Abs_pt_inverse)
       apply simp
       apply (intro mono_intros)
      apply (subst Abs_pt_inverse)
       apply simp
       apply (intro mono_intros)
      apply (rule conjI)
      using hyps(1) apply simp
      using hyps(2) by simp
  next
    case 2 thus ?case
      apply (subgoal_tac 
          "\<forall> P loc. 
                (wp (mu v. s) loc P env = {e |e. e \<in> defined loc \<and> update loc e (PdToSet (exec (mu v. s) senv (lookup loc e))) \<subseteq> E ` P})
                \<and> (wp_err (mu v. s) loc P env = {e |e. e \<in> defined loc \<and> update loc e (PdToSet (exec (mu v. s) senv (lookup loc e))) \<subseteq> E ` P \<union> {Err}})")
       apply simp
      apply simp
      apply (rule parallel_fixp_induct[where f="\<lambda> x. (\<lambda>loc. Abs_pt (\<lambda>P. wp s loc P (env((v, Tot) := fst x, (v, Par) := snd x))),
                  \<lambda>loc. Abs_pt (\<lambda>P. wp_err s loc P (env((v, Tot) := fst x, (v, Par) := snd x))))"and g="\<lambda> x. exec s (senv(v := x))"])
          apply (rule admissible_all)
          apply (rule admissible_all)
          apply (rule admissible_conj)
           apply (rule wp_mu_admissible)
          apply (rule wp_err_mu_admissible[simplified])
         apply (simp add: fst_Sup snd_Sup Sup_pt pd_Sup)
         apply (subst Abs_pt_inverse)
          apply simp
          apply (intro mono_intros)
         apply (subst Abs_pt_inverse)
          apply simp
          apply (intro mono_intros)
         apply clarsimp
      using update_inter_err_div apply blast
        apply (intro mono_intros)
       apply (rule monoI)
       apply (rule exec_mono)
       apply simp
      apply clarsimp
      apply (subst Abs_pt_inverse)
       apply simp
       apply (intro mono_intros)
      apply (subst Abs_pt_inverse)
       apply simp
       apply (intro mono_intros)
      apply (rule conjI)
      using hyps(1) apply simp
      using hyps(2) by simp
  }
qed

end
(*    using [[rule_trace]] apply rule
 *)