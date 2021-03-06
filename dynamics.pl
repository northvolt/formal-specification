%%
% Logic about state we keep in Dynamics goes here
% Note that the model keeps all state in the same place
% because it does not care about the underlying data layer
%%

:- ['auto.pl'].

% a productionorder is of the form prodorder(ProdOrderID, [JobIDs])
production_order(ProdOrderID, Jobs, ProdOrder) :-
    string(ProdOrderID), is_list(Jobs),
    ProdOrder = production_order(ProdOrderID, Jobs).

% convenience predicate creating the production order and the jobs it contains
% Jobs is a list of [UnitID-JobID-BoM] pairs, where BoM is optional
create_production_order(ProdOrderID, Jobs, OldState, NewState) :-
    foldl(create_job(ProdOrderID), Jobs, OldState, TempState),
    include([X]>>(X=(job(_, _, ProdOrderID, _, _))), TempState, CreatedJobs),
    maplist([J, ID]>>(J=job(_, ID, _, _, _)), CreatedJobs, JobIDs),
    production_order(ProdOrderID, JobIDs, ProdOrder),
    create(ProdOrder, TempState, NewState).

create_job(ProdOrderID, UnitID-JobID-BoM, OldState, NewState) :-
    job(UnitID, JobID, ProdOrderID, BoM, Job),
    create(Job, OldState, NewState).

% a job is of the form job(UnitID, JobID, BoM, Status)
% inputmaterials is a list of ItemID-Quantity pairs
% which is converted to BoM, a list of items (with name and quantity fields)
job(UnitID, JobID, ProdOrderID, Job) :-
    string(UnitID), string(JobID), string(ProdOrderID),
    job(UnitID, JobID, ProdOrderID, [], Job).

job(UnitID, JobID, ProdOrderID, InputMaterials, Job) :-
    string(UnitID), string(JobID), string(ProdOrderID), is_list(InputMaterials),
    maplist([X,Y]>>(X=Item-Q, Y=item(Item,Q)), InputMaterials, BoM),
    Job = job(UnitID, JobID, ProdOrderID, BoM, released).

job_status(released).
job_status(started).
job_status(ended).

% TODO: only indirect consumption for now!
% Theres indirect consumption which consumes from the generic stock of items
% and then there is consumption for a job, which consumes from the job quantity
% On load/unload we set startTime and quantity on the position.
% While the machine is running, the mapper updates the quantity on position based on time
% Nothing listens to the MaterialLoaded/MaterialUnloaded Events as of yet :)
% for 'default' consumption strategy, we set the startTime on load and start of job,
% using the latest of the two times as our actual start time.
% This time is used by the mapper to compute the amount consumed/produced
% within this job context

% warehouse(List) where List is a list of items with quantity
% always exists in the state and reflects the current items 

% consumeIndirect subtracts quantity from item amount in warehouse
consumeIndirect(Item, Quantity, OldState, NewState) :-
    selectchk(warehouse(List), OldState, TempState),
    selectchk(item(Item,AmountInWarehouse), List, TempList),
    NewAmount #= AmountInWarehouse - Quantity,
    NewWarehouse = warehouse([item(Item,NewAmount)|TempList]),
    NewState = [NewWarehouse|TempState].

get_active_job(UnitID, State, Job) :-
    Job = job(UnitID, _, _, _, started),
    exists(State, Job).

% MUTATIONS related to Dynamics D365
% TODO: code needs JobID AND UnitID because we cant go from jobID to unitID in dynamics rn
% This makes absolutely no sense and leads to horrible code
% It also means that right now, we need to verify that JobID and UnitID are in sync in the call

% TODO: looks like this condition does not exist in code: only one job with this id!
can_start_job(JobID, OldState) :-
    JobNotStarted = job(UnitID, JobID, _, _, released),
    exists(OldState, JobNotStarted),
    % condition: only one job can be active for a machine at a time
    % active means the job is started but not ended
    not(exists(OldState, job(UnitID, _, _, _, started))).

% job should already exist, and is simply updated
% jobs are created when product order that contains them is created!
start_job(JobID, OldState, NewState) :-
    can_start_job(JobID, OldState),
    JobNotStarted = job(UnitID, JobID, ProdOrderID, BoM, released),
    JobStarted = job(UnitID, JobID, ProdOrderID, BoM, started),
    update(JobNotStarted, JobStarted, OldState, TempState),
    % TODO: UnitID = MachineName ?
    update_interlock(UnitID, TempState, NewState).
    % TODO: update material interlock ?

% TODO: looks like this condition does not exist in code: only one job with this id!
can_end_job(JobID, OldState) :-
    JobStarted = job(_, JobID, _, _, started),
    exists(OldState, JobStarted).

end_job(JobID, OldState, NewState) :-
    can_end_job(JobID, OldState),
    JobStarted = job(UnitID, JobID, ProdOrderID, BoM, started),
    JobEnded = job(UnitID, JobID, ProdOrderID, BoM, ended),
    update(JobStarted, JobEnded, OldState, TempState),
    % TODO: UnitID = MachineName ?
    update_interlock(UnitID, TempState, TempState2),
    % TODO: update material interlock ?
    ( UnitID = "stacker"
    ->
        update_end_marker(JobID, TempState2, NewState)
    ;
        % only do something for stacker
        NewState = TempState2
    ).

:- begin_tests(job_mutations).

test(start_job_after_ending) :-
    machine("coater", Coater),
    job("coater", "jobid", "poid", ["PC-A"-1, "PC-B"-1], Job),
    northcloud(InitialState),
    actions([
        create_machine(Coater),
        create(Job),
        start_job("jobid"),
        end_job("jobid")
    ], InitialState, FinalState),
    assertion(not(can_start_job("jobid", FinalState))).

:- end_tests(job_mutations).
