-module(groupy).

-export([start/2, stop/0]).

start(Module, Sleep) ->
  Leader = worker:start("1", Module, 1, Sleep),
  register(a, Leader),
  register(b, worker:start("2", Module, 2, Leader, Sleep)),
  register(c, worker:start("3", Module, 3, Leader, Sleep)),
  register(d, worker:start("4", Module, 4, Leader, Sleep)),
  register(e, worker:start("5", Module, 5, Leader, Sleep)).

stop() ->
  a ! stop,
  b ! stop,
  c ! stop,
  d ! stop,
  e ! stop.
