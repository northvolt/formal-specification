% an event is always of the form e(Name, Actor, Target)
event(Name, Actor, Target, e(Name, Actor, Target)).

publish_event(Event, OldState, NewState) :-
    selectchk(events(List), OldState, TempState1),
    append(List, [Event], NewList),
    TempState2 = [events(NewList)|TempState1],
    handle_event(Event, TempState2, NewState),
    *writeln(Event).

add_pr(PR, OldState, NewState) :-
    selectchk(prs(List), OldState, TempState),
    append(List, [PR], NewList),
    NewState = [prs(NewList)|TempState].

% create a new sheet identity with the event grade
% then create a new PR with relevant information
handle_event(e("sheet_cut", Actor, Target), S, NS) :-
    create_identity_from_event("sheet", Actor, Target, S, S1),
    create_sheet_PR(Actor, Target, S1, NS).

handle_event(e("jellyroll_stacked", Actor, Target), S, NS) :-
    create_identity_from_event("jellyroll", Actor, Target, S, S1),
    create_stacking_PR(Actor, Target, S1, NS).

handle_event(e("jellyroll_pressed", Actor, Target), OldState, NewState) :-
    % make sure target exists already
    find(Target, OldState, Identity),
    create_jr_pressed_PR(Actor, Target, OldState, TempState),
    auto_start_or_end("hotpress", Identity, TempState, NewState).

create_identity_from_event(Name, Actor, Target, OldState, NewState) :-
    (    
        get_active_job(Actor, OldState, Job)
    ->
        Job = job(Actor, JobID, ProdOrderID, _BoM, started)
    ;
        JobID = "JOBNOTFOUND",
        ProdOrderID = "PONOTFOUND"
    ),
    % JobID + ProdOrderID are on IDRef in our code
    identity(Target, Name, JobID, ProdOrderID, Identity),
    create(Identity, OldState, NewState).

% a process result is of the form pr(Name, Target, JobID)
process_result(Name, Target, JobID, pr(Name, Target, JobID)).

create_process_result(Name, Actor, Target, OldState, NewState) :-
    (    
        get_active_job(Actor, OldState, Job)
    ->
        Job = job(Actor, JobID, _ProdOrderID, _BoM, started)
    ;
        % TODO: this illustrates a bug in our current implementation:
        % theres essentially a race between autostartjob and getting active job to populate PR with
        JobID = "JOBNOTFOUND"
    ),
    process_result(Name, Target, JobID, PR),
    add_pr(PR, OldState, NewState).

% Sheets

create_sheet_PR(Actor, Target, OldState, NewState) :-
    create_process_result("sheet_cut", Actor, Target, OldState, NewState).

% Jellyrolls

create_stacking_PR(Actor, Target, OldState, NewState) :-
    create_process_result("jr_stacked", Actor, Target, OldState, NewState).

create_jr_pressed_PR(Actor, Target, OldState, NewState) :-
    create_process_result("jr_pressed", Actor, Target, OldState, NewState).

:- begin_tests(stacking_events).

test(sheetcut) :-
    machine("stacker", EmptyStacker),
    event("sheet_cut", "stacker", "sheetid", Event),
    northcloud(State),
    actions([
        create_machine(EmptyStacker),
        create_production_order("poid", [
            "stacker"-"jobid"-[]
            ]),
        start_job("jobid"),
        publish_event(Event)
    ], State, FinalState),
    assertion(exists(FinalState, i("sheetid", "sheet",_,_))),
    % exactly one PR should have been created
    memberchk(prs([PR]), FinalState),
    assertion(PR = pr("sheet_cut","sheetid","jobid")).

:- end_tests(stacking_events).

