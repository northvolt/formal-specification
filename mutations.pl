%%%
% Logic about mutations goes here
% these are basically calls from the app that change state
% actions are a special separate case though
%%%

% TODO: code needs JobID AND UnitID because we cant go from jobID to unitID in dynamics rn
% This makes absolutely no sense and leads to horrible code
% It also means that right now, we need to verify that JobID and UnitID are in sync in the call

% TODO: looks like this condition does not exist in code: only one job with this id!
can_start_job(JobID, OldState) :-
    JobNotStarted = job(_, JobID, _, false, false),
    exists(OldState, JobNotStarted),
    % condition: only one job can be active for a machine at a time
    % active means the job is started but not ended
    not(exists(OldState, job(_, JobID, _, true, false))).

% job should already exist, and is simply updated
% jobs are created when product order that contains them is created!
start_job(JobID, OldState, NewState) :-
    can_start_job(JobID, OldState),
    JobNotStarted = job(UnitID, JobID, BoM, false, false),
    JobStarted = job(UnitID, JobID, BoM, true, false),
    update(JobNotStarted, JobStarted, OldState, TempState),
    % TODO: UnitID = MachineName ?
    request_release_interlock(UnitID, TempState, NewState).
    % TODO: update material interlock ?

% TODO: looks like this condition does not exist in code: only one job with this id!
can_end_job(JobID, OldState) :-
    JobStarted = job(_, JobID, _, true, false),
    exists(OldState, JobStarted).

end_job(JobID, OldState, NewState) :-
    can_end_job(JobID, OldState),
    JobStarted = job(UnitID, JobID, BoM, true, false),
    JobEnded = job(UnitID, JobID, BoM, true, true),
    update(JobStarted, JobEnded, OldState, TempState),
    % TODO: UnitID = MachineName ?
    request_set_interlock(UnitID, TempState, NewState).
    % TODO: update material interlock ?
    
:- begin_tests(job_mutations).

test(start_job_after_ending) :-
    northcloud(EmptyState),
    machine("stacker", Stacker),
    create_machine(Stacker, EmptyState, StartState),
    job("stacker", "jobid", ["PC-A"-1, "PC-B"-1], Job),
    create(Job, StartState, StateJobCreated),
    start_job("jobid", StateJobCreated, StateJobStarted),
    end_job("jobid", StateJobStarted, StateJobEnded),
    not(can_start_job("jobid", StateJobEnded)).

:- end_tests(job_mutations).
