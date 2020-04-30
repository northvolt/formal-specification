request_release_interlock(MachineName, OldState, NewState) :-
    get_machine(MachineName, OldState, Machine),
    (
        can_release_interlock(Machine, OldState)
    ->
        release_interlock(MachineName, OldState, NewState)
    ;
        % no update happens
        NewState = OldState
    ).
    % TODO: send interlock changed requested event

% release interlock has three conditions:
% - a job must be started for the machine
% - all requisite job inputs must be loaded on active input positions
%   where a requisite input is an member of the BoM with quantity > 0
% - all active output positions must have an itemholder, which can be
%   either empty or holding material that is on the BoM (even with quantity 0)
can_release_interlock(MachineName, State) :-
    get_machine(MachineName, State, Machine),
    Machine = m(Name, InputPositions, OutputPositions),
    % condition 1
    exists(State, job(Name, _, BoM)),
    % condition 2
    forall(member(JM-Quantity, BoM), (
            Quantity #= 0
        ;
            Quantity #> 0,
            member(in(ItemHolder, true), InputPositions),
            not(itemholder_is_empty(ItemHolder)),
            item_on_holder(JM, ItemHolder)
    )),
    % condition 3
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
                item_on_holder(Item, ItemHolder),
                item_on_bom(Item, BoM)
            )
        )
    )).

item_on_bom(Item, BoM) :-
    memberchk(Item-_, BoM).

release_interlock(Name, OldState, NewState) :-
    update(machine_config(Name, _), machine_config(Name, false), OldState, NewState).

% does not have a corresponding can_set function
% this is simply the inverse of request_release_interlock
request_set_interlock(MachineName, OldState, NewState) :-
    get_machine(MachineName, OldState, Machine),
    (
        can_release_interlock(Machine, OldState)
    ->
        % no update happens
        NewState = OldState
    ;
        release_interlock(MachineName, OldState, NewState)
    ).
    % TODO: send interlock changed requested event

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
            item_on_holder(Item, IH),
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

:- begin_tests(interlock).

test(release_interlock) :-
    northcloud(State),
    machine("stacker", EmptyStacker),
    item_on_holder("PC-A", AnodeInput),
    item_on_holder("PC-B", CathodeInput),
    load_holder_in_inputposition(AnodeInput, 1, EmptyStacker, NewStacker),
    load_holder_in_inputposition(CathodeInput, 3, NewStacker, Stacker),
    create_machine(Stacker, State, S1),
    job("stacker", "jobid", ["PC-A"-1, "PC-B"-1], Job),
    start_job(Job, S1, FinalState),
    assertion(can_release_interlock("stacker", FinalState)).

test(cannot_release_interlock_no_job) :-
    northcloud(State),
    machine("stacker", EmptyStacker),
    item_on_holder("PC-A", AnodeInput),
    item_on_holder("PC-B", CathodeInput),
    load_holder_in_inputposition(AnodeInput, 1, EmptyStacker, NewStacker),
    load_holder_in_inputposition(CathodeInput, 3, NewStacker, Stacker),
    create_machine(Stacker, State, FinalState),
    assertion(not(can_release_interlock("stacker", FinalState))).

test(cannot_release_interlock_material_mismatch) :-
    northcloud(State),
    machine("stacker", EmptyStacker),
    item_on_holder("PC-A", AnodeInput),
    item_on_holder("PC-C", CathodeInput),
    load_holder_in_inputposition(AnodeInput, 1, EmptyStacker, NewStacker),
    load_holder_in_inputposition(CathodeInput, 3, NewStacker, Stacker),
    create_machine(Stacker, State, S1),
    job("stacker", "jobid", ["PC-A"-1, "PC-B"-1], Job),
    start_job(Job, S1, FinalState),
    assertion(not(can_release_interlock("stacker", FinalState))).

test(cannot_release_interlock_incorrect_output_position) :-
    northcloud(State),
    machine("presser", EmptyPresser),
    item_on_holder("ItemName", ItemHolder),
    load_holder_in_inputposition(ItemHolder, 1, EmptyPresser, Presser),
    create_machine(Presser, State, S1),
    job("presser", "jobid", ["ItemName"-1], Job),
    start_job(Job, S1, FinalState),
    assertion(not(can_release_interlock("presser", FinalState))).
    
test(cannot_release_interlock_loaded_on_inactive) :-
    northcloud(State),
    machine("stacker", EmptyStacker),
    item_on_holder("PC-A", AnodeInput),
    item_on_holder("PC-B", CathodeInput),
    load_holder_in_inputposition(AnodeInput, 2, EmptyStacker, NewStacker),
    load_holder_in_inputposition(CathodeInput, 3, NewStacker, Stacker),
    create_machine(Stacker, State, S1),
    job("stacker", "jobid", ["PC-A"-1, "PC-B"-1], Job),
    start_job(Job, S1, FinalState),
    assertion(not(can_release_interlock("stacker", FinalState))).

:- end_tests(interlock).

:- begin_tests(material_interlock).

test(material_interlock_test1) :-
    northcloud(State),
    machine("stacker", EmptyStacker),
    create_machine(EmptyStacker, State, TempState),
    item_on_holder("PC-A", AnodeInput),
    item_on_holder("PC-B", CathodeInput),
    % using the actual actions instead of the underlying function directly
    % lets see if this breaks once we model the side-effects of the action
    load_input_material(AnodeInput, 1, "stacker", TempState, S1),
    load_input_material(AnodeInput, 2, "stacker", S1, S2),
    load_input_material(CathodeInput, 3, "stacker", S2, S3),
    load_input_material(CathodeInput, 4, "stacker", S3, StateAfterLoad),
    BoM = ["PC-A"-1, "PC-B"-1],
    get_machine("stacker", StateAfterLoad, Stacker),
    Stacker = m(_, InputPositions, OutputPositions),
    assertion((
        forall(member(IP, InputPositions), (
            not(material_interlock(IP, BoM))
        )),
        forall(member(OP, OutputPositions), (
            not(material_interlock(OP, BoM))
        ))
    )),
    job("stacker", "jobid", BoM, Job),
    start_job(Job, StateAfterLoad, FinalState),
    assertion(can_release_interlock("stacker", FinalState)).

:- end_tests(material_interlock).
