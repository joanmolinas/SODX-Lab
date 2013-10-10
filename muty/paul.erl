-module(paul).
-export([start/3, stop/0]).

start(Lock, Sleep, Work) ->
    register(l3, spawn(Lock, init,[3, [{l1,'node1@127.0.0.1'},{l2,'node2@127.0.0.1'},{l4,'node4@127.0.0.1'}]])),
    register(paul, spawn(worker, init, ["Paul", l3,43,Sleep,Work])),
    ok.

stop() ->
    paul ! stop,
    l3 ! stop.
