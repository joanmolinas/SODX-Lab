-module(ringo).
-export([start/3, stop/0]).

start(Lock, Sleep, Work) ->
    register(l2, spawn(Lock, init,[2, [{l1,'node1@127.0.0.1'},{l3,'node3@127.0.0.1'},{l4,'node4@127.0.0.1'}]])),
    register(ringo, spawn(worker, init, ["Ringo", l2,37,Sleep,Work])),
    ok.

stop() ->
    ringo ! stop,
    l2 ! stop.
