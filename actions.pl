%%%
% Logic about actions goes here
% Also state changes (sent directly from the mapper!)
%
% Actions have validation on whether you can take the action
% separately the underlying function has conditions for execution
% TODO: action Validate() does a condition check, which will call
% underlying function CanRun most of the time. This is checked again
% when we actually perform the action. This seems wasteful!
%
% Then there is side-effects to the actual function that the action
% takes its name from, such as releasing interlock when loading item
%%%

% Load an itemholder with item (material) on it into an input position
% Has a number of conditions and side-effects
% Semantics: itemholder, inputposition, state before, state after update
% Takes an index to the inputposition list and a machine, instead of 
% the position itself (as we do in the go code)
load_input_material(IH, IPIndex, MachineName, OldState, NewState) :-
    get_machine(MachineName, OldState, Machine),
    can_load_holder_in_inputposition(IH, IPIndex, Machine, OldState),
    load_holder_in_inputposition(IH, IPIndex, Machine, NewMachine),
    update(Machine, NewMachine, OldState, TempState),
    % TODO: consume material, set position counter and quantity
    request_release_interlock(MachineName, TempState, NewState).
    % TODO: update material interlock ?

% TODO: inconsistency in naming: load input mat vs output holder??
load_output_holder(IH, OPIndex, MachineName, OldState, NewState) :-
    get_machine(MachineName, OldState, Machine),
    can_load_holder_in_outputposition(IH, OPIndex, Machine, OldState),
    load_holder_in_outputposition(IH, OPIndex, Machine, NewMachine),
    update(Machine, NewMachine, OldState, TempState),
    % TODO: start position counter and quantity
    request_release_interlock(MachineName, TempState, NewState).
    % TODO: update material interlock ?

% Block / Unblock item ?!?

% underlying call is named UnloadHolder, which is more descriptive
% TODO: attempts to report to dynamics and unsetpositioncounter even
% before checking conditions in fs.UnloadHolder ?
% InOrOut is one of either 'in' or 'out' atoms
unload_material(InOrOut, Index, MachineName, OldState, NewState) :-
    get_machine(MachineName, OldState, Machine),
    Machine = m(MachineName, Inputs, Outputs),
    % select itemposition IP from either inputs or outputs
    (
        InOrOut = in,
        nth1(Index, Inputs, IP)
    ;
        InOrOut = out,
        nth1(Index, Outputs, IP)
    ),
    % report to dynamics, unset position counter, end process ?
    can_unload_holder(IP),
    unload_holder(InOrOut, Index, Machine, NewMachine),
    update(Machine, NewMachine, OldState, TempState),
    % update material interlock ?
    request_set_interlock(MachineName, TempState, NewState).

% Link item and holder? Happens implicit in the model so far.
% When do we ever call this action from the app? What is the usecase?
%
% Auto-Create Thing ?!?!?!