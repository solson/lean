import .clause .clausifier .cdcl_solver
open tactic expr monad super

private meta def theory_solver_of_tactic (th_solver : tactic unit) : cdcl.solver (option cdcl.proof_term) :=
do s ← state_t.read, ♯do
hyps ← return $ s↣trail↣for (λe, e↣hyp),
subgoal ← mk_meta_var s↣local_false,
goals ← get_goals,
set_goals [subgoal],
hvs ← for hyps (λhyp, assertv hyp↣local_pp_name hyp↣local_type hyp),
solved ← (do th_solver, now, return tt) <|> return ff,
set_goals goals,
if solved then do
  proof ← instantiate_mvars subgoal,
  proof' ← whnf proof, -- gets rid of the unnecessary asserts
  return $ some proof'
else
  return none

meta def cdcl_t (th_solver : tactic unit) : tactic unit := do
as_refutation, local_false ← target,
clauses ← clauses_of_context, clauses ← get_clauses_classical clauses,
for clauses (λc, do c_pp ← pp c, clause.validate c <|> fail c_pp),
res ← cdcl.solve (theory_solver_of_tactic th_solver) local_false clauses,
match res with
| (cdcl.result.unsat proof) := exact proof
| (cdcl.result.sat interp) :=
  let interp' := do e ← interp↣to_list, [if e↣2 = tt then e↣1 else not_ e↣1] in
  do pp_interp ← pp interp',
     fail (to_fmt "satisfying assignment: " ++ pp_interp)
end

meta def cdcl : tactic unit := cdcl_t skip
