% an event is always of the form e(Name, Actor, Target)
event(Name, Actor, Target, e(Name, Actor, Target)).

publish_event(Event, OldState, NewState) :-
    selectchk(events(List), OldState, TempState1),
    append(List, [Event], NewList),
    TempState2 = [events(NewList)|TempState1],
    handle_event(Event, TempState2, NewState),
    *writeln(Event).

% create a new sheet identity with the event grade
% then create a new PR with relevant information
handle_event(e("sheet_cut", _, Target), S, NS) :-
    create_sheet(Target, S, S1),
    create_sheet_PR(S1, NS).

handle_event(e("jellyroll_stacked", _, Target), S, NS) :-
    create_jellyroll(Target, S, S1),
    create_stacking_PR(S1, NS).

handle_event(e("jellyroll_pressed", _, Target), OldState, NewState) :-
    find(Target, OldState, _),
    create_jr_pressed_PR(OldState, TempState),
    auto_start_or_end("hotpress", Target, TempState, NewState).

% a process result is of the form pr(Name)
process_result(Name, pr(Name)).

% Sheets

create_sheet(ID, OldState, NewState) :-
    identity(ID, "sheet", Sheet),
    create(Sheet, OldState, NewState).

create_sheet_PR(OldState, NewState) :-
    process_result("sheet", PR),
    create(PR, OldState, NewState).

% Jellyrolls

create_jellyroll(ID, OldState, NewState) :-
    identity(ID, "jellyroll", JellyRoll),
    create(JellyRoll, OldState, NewState).

create_stacking_PR(OldState, NewState) :-
    process_result("stacking", PR),
    create(PR, OldState, NewState).

create_jr_pressed_PR(OldState, NewState) :-
    process_result("jr_pressed", PR),
    create(PR, OldState, NewState).

:- begin_tests(stacking_events).

% example test, heavily annotated
test(sheetcut) :-
    % instantiate the data model, holds all state. starts empty
    northcloud(State),
    % publish an event / trigger a mutation
    event("sheet_cut", "stacker", "sheetid", Event),
    % notice how state changes are reflected in a new Variable
    publish_event(Event, State, FinalState),
    % verify resulting data updates are correct
    assertion(exists(FinalState, i("sheetid", "sheet"))),
    assertion(exists(FinalState, pr("sheet"))).

% example test, hopefully self explanatory
test(jellyrollstacked) :-
    northcloud(State),
    event("jellyroll_stacked", "stacker", "jrid", Event),
    publish_event(Event, State, FinalState),
    assertion(exists(FinalState, i("jrid", "jellyroll"))),
    assertion(exists(FinalState, pr("stacking"))).

:- end_tests(stacking_events).

