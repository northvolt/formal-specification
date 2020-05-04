% a machine is of the form m(Name, InputPositions, OutputPositions)
% A machine is known as a FactoryUnit in the model ?

% when we create a machine, make sure to create config for it too
create_machine(Machine, OldState, NewState) :-
    Machine = m(Name, _, _),
    create(Machine, OldState, TempState),
    config(Name, Config),
    create(Config, TempState, NewState).

% from slurry mixing up to (not including) stacker, theres 1 anode and 1 cathode version
% of each machine

% input can either be A side or B side (we need to coat both in separate jobs)
machine("coater", m("coater", [Foil1, Foil2, Slurry], [CoatedFoil1, CoatedFoil2])) :-
    inputposition(empty, true, Foil1),
    inputposition(empty, false, Foil2),
    inputposition(empty, true, Slurry),
    outputposition(empty, true, CoatedFoil1),
    outputposition(empty, false, CoatedFoil2).

machine("presser", m("presser", [JumboRoll], [PressedJumboRoll])) :-
    inputposition(empty, true, JumboRoll),
    outputposition(empty, true, PressedJumboRoll).

% optionally (for cylindrical cells): slitter and surface treatment

machine("notcher", m("notcher", [Pressed1, Pressed2], [Pancake1, Pancake2])) :-
    inputposition(empty, true, Pressed1),
    inputposition(empty, false, Pressed2),
    outputposition(empty, true, Pancake1),
    outputposition(empty, false, Pancake2).

machine("stacker", m("stacker", [Anode1, Anode2, Cathode1, Cathode2], [])) :-
    inputposition(empty, true, Anode1),
    inputposition(empty, false, Anode2),
    inputposition(empty, true, Cathode1),
    inputposition(empty, false, Cathode2).

% cell assembly
%
% formation & aging

% machine_config is of the form machine_config(Name, Interlocked)
config(Name, Config) :-
    Config = machine_config(Name, false).

% TODO: note that in our model we have split inputposition from inputpositionstate
% state is state as reported by mapper at that time, inputposition is updated constantly
% NOTE how empty positions and empty itemholders are indicated using 'empty' atom
% an inputposition is of the form in(ItemHolder, Active)
inputposition(ItemHolder, Boolean, in(ItemHolder, Boolean)).
% an outputposition is of the form out(ItemHolder, Active)
outputposition(ItemHolder, Boolean, out(ItemHolder, Boolean)).

position_is_empty(in(empty, _)).
position_is_empty(out(empty,_)).

% itemholders hold one item/material (?)
item_on_holder(ItemName, Quantity, itemholder(item(ItemName, Quantity))).

itemholder_is_empty(itemholder(empty)).

% item is of the form item(ItemName, Quantity)

% Why are these checked on the function, not on the action?
% They do bubble up. Weird to separate action from func here
% - position must be empty
% - holder must have an item
% - material must match job if job has started
% - itemholder must not be registered as loaded anywhere else
can_load_holder_in_inputposition(IH, Index, Machine, _State) :-
    IH = itemholder(_),
    Machine = m(_, Inputs, _),
    nth1(Index, Inputs, IP),
    position_is_empty(IP),
    not(itemholder_is_empty(IH)).
    % TODO: material is on BoM for Job if Job active for Machine
    % TODO: IH not linked to position? automatic in this model

% Index counts from 1, more convenient for non-programmers
% this is a state update, so we have machine before and after
% Semantics: itemholder to load, index in inputs, machine before, machine after update
% so load_holder_in_inputposition(itemholder(Item), 2, M, NM) evaluates NM to
% the machine M with the itemholder holding Item in the 2nd input position
load_holder_in_inputposition(IH, Index, Machine, NewMachine) :-
    IH = itemholder(_),
    Machine = m(Name, Inputs, Outputs),
    nth1(Index, Inputs, IP, Rem),
    position_is_empty(IP),
    IP = in(_, State),
    NewIP = in(IH, State),
    nth1(Index, NewInputs, NewIP, Rem),
    NewMachine = m(Name, NewInputs, Outputs).

% - position must be empty
% - holder must be empty 
% - itemholder must not be registered as loaded anywhere else
can_load_holder_in_outputposition(IH, Index, Machine, _State) :-
    IH = itemholder(_),
    Machine = m(_, _, Outputs),
    nth1(Index, Outputs, IP),
    position_is_empty(IP),
    itemholder_is_empty(IH).
    % TODO: IH not linked to position? automatic in this model

% Semantics: see inputposition
load_holder_in_outputposition(IH, Index, Machine, NewMachine) :-
    IH = itemholder(_),
    Machine = m(Name, Inputs, Outputs),
    nth1(Index, Outputs, OP, Rem),
    position_is_empty(OP),
    OP = out(_, State),
    NewOP = out(IH, State),
    nth1(Index, NewOutputs, NewOP, Rem),
    NewMachine = m(Name, Inputs, NewOutputs).

% - position cannot be empty or there would be nothing to unload
% - position cannot be in active use, which is defined as:
%   the machine is in execute AND the position is active
% TODO: machine PackML state
can_unload_holder(Position) :-
    not(position_is_empty(Position)),
    (Position = in(_, State) ; Position = out(_, State)),
    State = true.

unload_holder_from_inputposition(Index, Machine, NewMachine) :-
    Machine = m(Name, Inputs, Outputs),
    nth1(Index, Inputs, IP, Rem),
    IP = in(_, State),
    NewIP = in(empty, State),
    nth1(Index, NewInputs, NewIP, Rem),
    NewMachine = m(Name, NewInputs, Outputs).

unload_holder_from_outputposition(Index, Machine, NewMachine) :-
    Machine = m(Name, Inputs, Outputs),
    nth1(Index, Outputs, OP, Rem),
    OP = out(_, State),
    NewOP = out(empty, State),
    nth1(Index, NewOutputs, NewOP, Rem),
    NewMachine = m(Name, Inputs, NewOutputs).
