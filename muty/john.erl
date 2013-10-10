-module(john).
-export([start/3, stop/0]).

start(Lock, Sleep, Work) ->
    register(l1, spawn(Lock, init,[1, [l2,l3,l4]])),
    register(john, spawn(worker, init, ["John", l1,34,Sleep,Work])),
    ok.

stop() ->
    john ! stop,
    l1 ! stop.