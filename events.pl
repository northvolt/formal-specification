% an event is always of the form e(Name, Actor, Target)
event(Name, Actor, Target, e(Name, Actor, Target)).

publish_event(Event, OldState, NewState) :-
    Event = e(EventName, _, _),
    select(events(List), OldState, TempState1),
    append(List, [Event], NewList),
    TempState2 = [events(NewList)|TempState1],
    handle_event(EventName, TempState2, NewState),
    *writeln(Event).

% create a new sheet identity with the event grade
% then create a new PR with relevant information
handle_event("sheet_cut", S, NS) :-
    create_sheet(S, S1),
    create_sheet_PR(S1, NS).

handle_event("jellyroll_stacked", S, NS) :-
    create_jellyroll(S, S1),
    create_stacking_PR(S1, NS).

% a process result is of the form pr(Name)
process_result(Name, pr(Name)).

% Sheets

create_sheet(OldState, NewState) :-
    identity("sheet", Sheet),
    create(Sheet, OldState, NewState).

create_sheet_PR(OldState, NewState) :-
    process_result("sheet", PR),
    create(PR, OldState, NewState).

% Jellyrolls

create_jellyroll(OldState, NewState) :-
    identity("jellyroll", JellyRoll),
    create(JellyRoll, OldState, NewState).

create_stacking_PR(OldState, NewState) :-
    process_result("stacking", PR),
    create(PR, OldState, NewState).

:- begin_tests(stacking).

% example test, heavily annotated
test(sheetcut) :-
    % instantiate the data model, holds all state. starts empty
    northcloud(State),
    % publish an event / trigger a mutation
    event("sheet_cut", "stacker", "sheetid", Event),
    % notice how state changes are reflected in a new Variable
    publish_event(Event, State, FinalState),
    % verify resulting data updates are correct
    assertion(exists(FinalState, i("sheet"))),
    assertion(exists(FinalState, pr("sheet"))).

% example test, hopefully self explanatory
test(jellyrollstacked) :-
    northcloud(State),
    event("jellyroll_stacked", "stacker", "jrid", Event),
    publish_event(Event, State, FinalState),
    assertion(exists(FinalState, i("jellyroll"))),
    assertion(exists(FinalState, pr("stacking"))).

% copy of integration test for stacking
/*
test(wuxilead) :-
    northcloud(State),
    % get the definition of the stacker machine and add it to known state
    machine("stacker", Stacker),
    create(Stacker, State, S1),
    job("stacker", "jobid", Job),
    start_job(Job, S1, S2),
    % prepare stacking machine, meaning:
    %% for both anode and cathode, create an item and itemholder
    %% and load them both as input materials on the stacker
    item_on_holder("PC-A", AnodeInput),
    item_on_holder("PC-B", CathodeInput),
    % TODO: in our model this loading of itemholder into position
    % is an action called LoadInputMaterial that should be tested
    Stacker = m(_, InputPositions, _),
    InputPositions = [in(AnodeInput, true), _, in(CathodeInput, true), _],
    % publish sheet_cut events
    % TODO: publish a whole lot of them (see integration test)
    event("sheet_cut", "stacker", "sheetid", SheetEvent),
    publish_event(SheetEvent, S2, S3),
    % TODO: verify all sheets and sheet PRs have been created
    % publish two jellyroll_stacked events
    % TODO: actually publish 2 instead of just the 1
    event("jellyroll_stacked", "stacker", "jrid", JREvent),
    publish_event(JREvent, S3, S4),
    % TODO: verify two jellyroll identities and corresponding PRs have been created
    % end job
    end_job(Job, S4, FinalState),
    % TODO final assertions
    assertion(exists(FinalState, i("jellyroll"))).
*/
    
:- end_tests(stacking).

