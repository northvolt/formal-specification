% helper functions for writing readable tests
% and debugging them

% List is a list of predicates that change state
% last two args of each should be OldState/NewState
actions(List, OldState, NewState) :-
    foldl([X,Y,Z]>>call(X, Y, Z), List, OldState, NewState).

% same as above but prints each state
actions_debug(List, OldState, NewState) :-
    foldl([X,Y,Z]>>(call(X, Y, Z), writeln(Z)), List, OldState, NewState).

changed_since(OldState, NewState, ChangedSet) :-
    subtract(NewState, OldState, ChangedSet).

filter_entities(Predicate, List, Filtered) :-
    include([X]>>(X =.. [Predicate|_]), List, Filtered).

% EXAMPLE
% multiple tests can exist in a group
% groups are declared as follows
:- begin_tests(example_group).

% a test belonging to the group is declared within this block, as
test(example_name) :-
    % each test should have 3 parts:
    % init, actions and assertions
    % they can repeat within a test

    % init declares the things we want to reason about
    event("sheet_cut", "stacker", "sheetid", Event),
    % actions change state
    northcloud(InitialState),
    actions([ publish_event(Event) ], InitialState, FinalState),
    % assertions check truth/validity
    assertion(exists(FinalState, i("sheetid", "sheet"))).

% groups need to be closed with end_tests/1
:- end_tests(example_group).

% tests can succeed with a warning if there was a choicepoint:
% ideally we reason semi-deterministically so choicepoints indicate bad code
% the test passing is still valid, but the code leaves possible ambiguities
