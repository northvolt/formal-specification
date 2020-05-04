%%
% Logic about state we keep in Dynamics goes here
% Note that the model keeps all state in the same place
% because it does not care about the underlying data layer
%%

% a job is of the form job(UnitID, JobID, BoM, Started, Ended)
% inputmaterials is a list of ItemID-Quantity pairs
% which is converted to BoM, a list of items (with name and quantity fields)
job(UnitID, JobID, Job) :-
    job(UnitID, JobID, [], Job).

job(UnitID, JobID, InputMaterials, Job) :-
    maplist([X,Y]>>(X=Item-Q, Y=item(Item,Q)), InputMaterials, BoM),
    Job = job(UnitID, JobID, BoM, false, false).

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
    select(warehouse(List), OldState, TempState),
    select(item(Item,AmountInWarehouse), List, TempList),
    NewAmount #= AmountInWarehouse - Quantity,
    NewWarehouse = warehouse([item(Item,NewAmount)|TempList]),
    NewState = [NewWarehouse|TempState].
