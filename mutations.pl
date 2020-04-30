%%%
% Logic about mutations goes here
% these are basically calls from the app that change state
% actions are a special separate case though
%%%

% job should already exist, and is simply updated
% jobs are created when product order that contains them is created!
start_job(Job, OldState, NewState) :-
    create(Job, OldState, NewState).

end_job(_,_,_).
