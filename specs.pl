% Triska trick: declarative debugging operator
:- op(920,fy, *).
*_.

:- use_module(library(clpfd)).

:- ['tests.pl'].

% models of part of our system. basic structure
:- ['machines.pl'].
:- ['events.pl'].
:- ['actions.pl'].
:- ['dynamics.pl'].

% models of specific, more involved logic cases with tests
:- ['interlock.pl'].

%%%
% State is a simple set of identities
% We cannot do actual changes to state in Prolog,
% only relating two state sets: the set before and after the change
% We get to keep both and refer to both
%%%

% northcloud is our entire data model, the initial state
% its just a simple collection of identities, prs, jobs etc
% some default groups of data are initialised to make this a little simpler
% warehouse is used in dynamics.pl and events in events.pl
northcloud(InitialState) :-
    InitialState = [warehouse([]), events([])].

% an identity is of the from i(Name)
identity(Name, Type, i(Name, Type)).

% create adds the identity/pr/job to our data model
create(X, State, [X|State]).

% helper funcs to get identities by name
get_machine(MachineName, State, Machine) :-
    Machine = m(MachineName, _, _),
    memberchk(Machine, State).
get_config(MachineName, State, Config) :-
    Config = machine_config(MachineName, _),
    memberchk(Config, State).
get_job(JobID, State, Job) :-
    Job = job(_, JobID, _, _, _),
    memberchk(Job, State).

% select removes from the list State
% since we dont care about order we can just append at the head
% assumes that exactly one of X exists in state
update(X, NewX, State, NewState) :-
    selectchk(X, State, Temp),
    NewState = [NewX|Temp].

exists(State, Identity) :-
    memberchk(Identity, State).

find(Name, State, Identity) :-
    Identity = i(Name, _),
    memberchk(Identity, State).
