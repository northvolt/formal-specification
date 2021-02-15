%%
% Logic about auto starting and ending of jobs
% for multi-operation routes is collected here
% so as to not clutter the dynamics.pl file
%%

auto_start_or_end(UnitID, Target, OldState, NewState) :-
    Target = i(_,_,_,POID),
    Job = job(UnitID, JobID, POID, _, Status),
    exists(OldState, Job),
    (
        Status = released
    ->
        auto_start_job(UnitID, Job, OldState, NewState)
    ;
        Status = started,
        % check if target is last in job, then end it
        writeln([JobID, Target]),
        ( exists(OldState, jobmarker(JobID, Target))
        ->
            auto_end_job(JobID, OldState, NewState)
        ;
            OldState = NewState
        )
    % TODO: what if Status = ended?
    ).

auto_start_job(UnitID, Job, OldState, NewState) :-
    (
        get_active_job(UnitID, OldState, CurrentJob),
        Job \= CurrentJob
    ->
        CurrentJob = job(_, CJobID, _, _, _),
        end_job(CJobID, OldState, TempState)
    ;
        % no changes need to be made
        OldState = TempState
    ),
    Job = job(_, JobID, _, _, _),
    start_job(JobID, TempState, NewState).

update_end_marker(JobID, OldState, NewState) :-
    memberchk(prs(PRs), OldState),
    include(=(pr("jr_stacked", _, JobID)), PRs, JobPRs),
    reverse(JobPRs, [LastPR|_]),
    LastPR = pr(_, Target, _),
    create(jobmarker(JobID, Target), OldState, NewState).

auto_end_job(JobID, OldState, NewState) :-
    end_job(JobID, OldState, NewState).

:- begin_tests(cell_assembly).

test(auto_start_job) :-
    % init
    machine("stacker", Stacker),
    machine("hotpress", HotPress),
    event("jellyroll_stacked", "stacker", "jrid", StackedEvent),
    event("jellyroll_pressed", "hotpress", "jrid", PressedEvent),

    % actions
    northcloud(InitialState),
    actions([
        create_machine(Stacker),
        create_machine(HotPress),
        create_production_order("poid", [
            "stacker"-"jobid1"-["PC-A"-1, "PC-B"-1],
            "hotpress"-"jobid2"-[]
            ]),
        % start the stacker job, not the hotpress one
        start_job("jobid1")
    ], InitialState, StateStackerStarted),
    % split these state changes since we want to refer back
    % to the state immediately after we start the stacker job
    actions([
        publish_event(StackedEvent),
        publish_event(PressedEvent)
    ], StateStackerStarted, FinalState),

    % assumptions
    changed_since(StateStackerStarted, FinalState, ChangedSet),
    filter_entities(job, ChangedSet, Jobs),
    % check that the only job that changed since creation is
    % the job for the hotpress, which has started
    assertion(Jobs = [job("hotpress",_,_,_,started)]).

test(auto_end_job) :-
    % init
    machine("stacker", Stacker),
    machine("hotpress", HotPress),
    event("jellyroll_stacked", "stacker", "jr1", StackedEvent1),
    event("jellyroll_pressed", "hotpress", "jr1", PressedEvent1),
    event("jellyroll_stacked", "stacker", "jr2", StackedEvent2),
    event("jellyroll_pressed", "hotpress", "jr2", PressedEvent2),

    % actions
    northcloud(InitialState),
    actions([
        create_machine(Stacker),
        create_machine(HotPress),
        create_production_order("poid1", [
            "stacker"-"jobid11"-[],
            "hotpress"-"jobid12"-[]
            ]),
        create_production_order("poid2", [
            "stacker"-"jobid21"-[],
            "hotpress"-"jobid22"-[]
            ]),
        start_job("jobid11"),
        publish_event(StackedEvent1),
        end_job("jobid11"),
        start_job("jobid21"),
        publish_event(StackedEvent2),
        publish_event(PressedEvent1),
        publish_event(PressedEvent2)
    ], InitialState, FinalState),

    % assumptions
    get_job("jobid12", FinalState, Job),
    Job = job(_, _, _, _, Status),
    assertion(Status = ended).

:- end_tests(cell_assembly).
