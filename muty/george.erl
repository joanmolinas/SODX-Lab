-module(george).
-export([start/3, stop/0]).

start(Lock, Sleep, Work) ->
    register(l4, spawn(Lock, init,[4, [l1,l2,l3]])),
    register(george, spawn(worker, init, ["George",l4,72,Sleep,Work])),
    ok.

stop() ->
    george ! stop,
    l4 ! stop.