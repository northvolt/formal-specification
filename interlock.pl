update_interlock(Name, OldState, NewState) :-
    get_machine(Name, OldState, Machine),
    (
        check_interlock_conditions(Machine, OldState)
    ->
        update(machine_config(Name, _), machine_config(Name, false), OldState, NewState)
    ;
        update(machine_config(Name, _), machine_config(Name, true), OldState, NewState)
    ).
    % TODO: send interlock changed requested event

% this is a mutation that overrides interlock, allowing machine to run
% _despite_ any interlock conditions failing. Emergency case
force_release_interlock(Name, OldState, NewState) :-
    update(machine_config(Name, _), machine_config(Name, false), OldState, NewState).

% different machines have different conditions to check
% each condition is permissive: if it succeeds, interlock should _not_ be set
% this predicate succeeding means interlock should _not_ be set
check_interlock_conditions(Machine, State) :-
    Machine = m(Name, _, _),
    get_interlock_conditions(Name, Conditions),
    forall(member(C, Conditions), (
        call(C, Machine, State)
    )).

get_interlock_conditions("presser", [job_started, mbom, output]).
get_interlock_conditions("coater",  [job_started, mbom, output]).
get_interlock_conditions("stacker", [job_started]).

% a job must be started for the machine
job_started(Machine, State) :-
    Machine = m(Name, _, _),
    exists(State, job(Name, _, _, _, started)).

% all requisite job inputs must be loaded on active input positions
% where a requisite input is an member of the BoM with quantity > 0
mbom(Machine, State) :-
    Machine = m(Name, InputPositions, _),
    exists(State, job(Name, _, _, BoM, started)),
    forall(member(item(JM,Quantity), BoM), (
            Quantity #= 0
        ;
            Quantity #> 0,
            member(iip(ItemHolder, true), InputPositions),
            not(itemholder_is_empty(ItemHolder)),
            item_on_holder(JM, _, ItemHolder)
    )).

% all active output positions must have an itemholder, which can be
% either empty or holding material that is on the BoM (even with quantity 0)
output(Machine, State) :-
    Machine = m(Name, _, OutputPositions),
    exists(State, job(Name, _, _, BoM, started)),
    forall(member(OutputPosition, OutputPositions), (
        OutputPosition = out(ItemHolder, Status),
        (
            Status = false
        ;
            Status = true,
            not(position_is_empty(OutputPosition)),    
            (
                itemholder_is_empty(ItemHolder)
            ;
                not(itemholder_is_empty(ItemHolder)),
                item_on_holder(Item, _, ItemHolder),
                item_on_bom(Item, BoM)
            )
        )
    )).

% check whether the item is on the bill of materials, ignoring quantities
item_on_bom(ItemName, BoM) :-
    memberchk(item(ItemName,_), BoM).

% if a position is material interlocked, it cannot be set to active
% the conditions depend on whether it is an input or output position
material_interlock(IP, BoM) :-
    IP = in(IH, false),
    (
        position_is_empty(IP) 
    ;
        not(position_is_empty(IP)),
        (
            itemholder_is_empty(IH)
        ;
            not(itemholder_is_empty(IH)),
            item_on_holder(Item, _, IH),
            not(item_on_bom(Item, BoM))
        )
    ).

material_interlock(OP, _) :-
    OP = out(IH, false),
    (
        position_is_empty(OP)
    ;
        not(position_is_empty(OP)),
        not(itemholder_is_empty(IH))
    ).

% calling update_interlock manually assumes proper triggers have been set up
% these should be called from actions taken to reach the starting state
:- begin_tests(interlock).

test(release_interlock) :-
    northcloud(State),
    machine("stacker", EmptyStacker),
    item_on_holder("PC-A", 1, AnodeInput),
    item_on_holder("PC-B", 1, CathodeInput),
    load_holder_in_inputposition(AnodeInput, 1, EmptyStacker, NewStacker),
    load_holder_in_inputposition(CathodeInput, 3, NewStacker, Stacker),
    create_machine(Stacker, State, S1),
    job("stacker", "jobid", "poid", ["PC-A"-1, "PC-B"-1], Job),
    create(Job, S1, S2),
    start_job("jobid", S2, FinalState),
    assertion(not(is_interlocked("stacker", FinalState))).

test(cannot_release_interlock_no_job) :-
    northcloud(State),
    machine("stacker", EmptyStacker),
    item_on_holder("PC-A", 1, AnodeInput),
    item_on_holder("PC-B", 1, CathodeInput),
    load_holder_in_inputposition(AnodeInput, 1, EmptyStacker, NewStacker),
    load_holder_in_inputposition(CathodeInput, 3, NewStacker, Stacker),
    create_machine(Stacker, State, FinalState),
    assertion(is_interlocked("stacker", FinalState)).

test(cannot_release_interlock_material_mismatch) :-
    northcloud(State),
    machine("presser", EmptyPresser),
    item_on_holder("PC-A", 1, AnodeInput),
    load_holder_in_inputposition(AnodeInput, 1, EmptyPresser, NewPresser),
    create_machine(NewPresser, State, S1),
    job("presser", "jobid", "poid", ["PC-B"-1], Job),
    create(Job, S1, S2),
    start_job("jobid", S2, FinalState),
    assertion(is_interlocked("presser", FinalState)).

test(cannot_release_interlock_incorrect_output_position) :-
    northcloud(State),
    machine("presser", EmptyPresser),
    item_on_holder("ItemName", 1, ItemHolder),
    load_holder_in_inputposition(ItemHolder, 1, EmptyPresser, Presser),
    create_machine(Presser, State, S1),
    job("presser", "jobid", "poid", ["ItemName"-1], Job),
    create(Job, S1, S2),
    start_job("jobid", S2, FinalState),
    assertion(is_interlocked("presser", FinalState)).
    
test(cannot_release_interlock_loaded_on_inactive) :-
    northcloud(State),
    machine("notcher", EmptyNotcher),
    item_on_holder("PC-A", 1, AnodeInput),
    load_holder_in_inputposition(AnodeInput, 2, EmptyNotcher, NewNotcher),
    create_machine(NewNotcher, State, S1),
    job("notcher", "jobid", "poid", ["PC-A"-1], Job),
    create(Job, S1, S2),
    start_job("jobid", S2, FinalState),
    assertion(is_interlocked("notcher", FinalState)).

test(force_release_interlock) :-
    northcloud(State),
    machine("stacker", EmptyStacker),
    item_on_holder("PC-A", 1, AnodeInput),
    item_on_holder("PC-B", 1, CathodeInput),
    load_holder_in_inputposition(AnodeInput, 1, EmptyStacker, NewStacker),
    load_holder_in_inputposition(CathodeInput, 3, NewStacker, Stacker),
    create_machine(Stacker, State, S1),
    force_release_interlock("stacker", S1, FinalState),
    assertion(not(is_interlocked("stacker", FinalState))).

:- end_tests(interlock).

:- begin_tests(coater_interlock).

test(winder_rotated) :-
    northcloud(EmptyState),
    update(warehouse(_), warehouse([item("PC-A",42), item("PC-B",42)]), EmptyState, State),
    machine("coater", EmptyCoater),
    create_machine(EmptyCoater, State, S1),
    item_on_holder("PC-A", 1, Input),
    % load on the inactive position
    load_input_material(Input, 2, "coater", S1, S2),
    job("coater", "jobid", "poid", ["PC-A"-1], Job),
    create(Job, S2, S3),
    start_job("jobid", S3, S4),
    % PLC switches active position
    winder_rotated("coater", S4, FinalState),
    assertion(not(is_interlocked("stacker", FinalState))).

:- end_tests(coater_interlock).

:- begin_tests(material_interlock).

% attempting to clean up and standardize test format
% first step towards writing tests in a DSL ?
test(material_interlock_test2) :-
    % init, create entities to reason about
    machine("stacker", EmptyStacker),
    item_on_holder("PC-A", 1, AnodeInput),
    item_on_holder("PC-B", 1, CathodeInput),
    BoM = [item("PC-A",1), item("PC-B",1)],

    % actions, i.e. whatever manipulates state
    % foldl weaves state changes through predicates whose last two arguments are
    % OldState and NewState.
    northcloud(InitialState),
    actions([
        update(warehouse(_), warehouse([item("PC-A",42), item("PC-B",42)])),
        create_machine(EmptyStacker),
        load_input_material(AnodeInput, 1, "stacker"),
        load_input_material(AnodeInput, 2, "stacker"),
        load_input_material(CathodeInput, 3, "stacker"),
        load_input_material(CathodeInput, 4, "stacker"),
        create_production_order("poid", [
            "stacker"-"jobid"-["PC-A"-1, "PC-B"-1]
            ]),
        start_job("jobid")
    ], InitialState, FinalState),

    % assumptions, i.e. things to check after test setup
    get_machine("stacker", FinalState, Stacker),
    Stacker = m(_, InputPositions, OutputPositions),
    assertion((
        forall(member(IP, InputPositions), (
            not(material_interlock(IP, BoM))
        )),
        forall(member(OP, OutputPositions), (
            not(material_interlock(OP, BoM))
        ))
    )),
    assertion(not(is_interlocked("stacker", FinalState))).

:- end_tests(material_interlock).
