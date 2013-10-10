-module(ringo).
-export([start/3, stop/0]).

start(Lock, Sleep, Work) ->
    register(l2, spawn(Lock, init,[2, [l1,l3,l4]])),
    register(ringo, spawn(worker, init, ["Ringo", l2,37,Sleep,Work])),
    ok.

stop() ->
    ringo ! stop,
    l2 ! stop.