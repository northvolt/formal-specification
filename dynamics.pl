%%
% Logic about state we keep in Dynamics goes here
% Note that the model keeps all state in the same place
% because it does not care about the underlying data layer
%%

% a job is of the form job(UnitID, JobID, InputMaterials)
% inputmaterials, or BoM, is a list of ItemID-Quantity pairs
job(UnitID, JobID, Job) :-
    job(UnitID, JobID, [], Job).
job(UnitID, JobID, InputMaterials, job(UnitID, JobID, InputMaterials)).

% what entity in dynamics cares about consumption?
% quantity consumed/produced is kept track of on the itemposition?
% reported to dynamics upon unload or on load depending on consumptionstrategy?
% how does startTime factor in exactly? to infer the actual quantity?
% what listens to the MaterialUnloaded Event? Anything?
