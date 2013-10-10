-module(paul).
-export([start/3, stop/0]).

start(Lock, Sleep, Work) ->
    register(l3, spawn(Lock, init,[3, [l1,l2,l4]])),
    register(paul, spawn(worker, init, ["Paul", l3,43,Sleep,Work])),
    ok.

stop() ->
    paul ! stop,
    l3 ! stop.