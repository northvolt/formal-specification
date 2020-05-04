% Triska trick: declarative debugging operator
:- op(920,fy, *).
*_.

:- use_module(library(clpfd)).

% models of part of our system. basic structure
:- ['machines.pl'].
:- ['events.pl'].
:- ['actions.pl'].
:- ['mutations.pl'].
:- ['dynamics.pl'].

% models of specific, more involved logic cases with tests
:- ['interlock.pl'].

% a process result is of the form pr(Name)
process_result(Name, pr(Name)).

%%%
% State is a simple set of identities
% We cannot do actual changes to state in Prolog,
% only relating two state sets: the set before and after the change
% We get to keep both and refer to both
%%%

% northcloud is our entire data model, the initial state
% its just a simple collection of identities, prs, jobs etc
northcloud(InitialState) :-
    InitialState = [warehouse([])].

% an identity is of the from i(Name)
identity(Name, i(Name)).

% create adds the identity/pr/job to our data model
create(X, State, [X|State]).

% helper funcs to get identities by name
get_machine(MachineName, State, Machine) :-
    Machine = m(MachineName, _, _),
    memberchk(Machine, State).
get_config(MachineName, State, Config) :-
    Config = machine_config(MachineName, _),
    memberchk(Config, State).

% select removes from the list State
% since we dont care about order we can just append at the head
% assumes that exactly one of X exists in state
update(X, NewX, State, NewState) :-
    select(X, State, Temp),
    NewState = [NewX|Temp].

exists(State, Identity) :-
    memberchk(Identity, State).
