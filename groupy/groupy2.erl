-module(groupy2).

-export([start/6, stop/1]).

start(Module, Sleep, Atom, Id, Rand, leader) ->
  register(Atom, worker:start(Id, Module, Rand, Sleep));
start(Module, Sleep, Atom, Id, Rand, Leader) ->
  register(Atom, worker:start(Id, Module, Rand, Leader, Sleep)).
  
stop(Atom) ->
  Atom ! stop.
  