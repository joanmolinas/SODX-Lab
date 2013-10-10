-module(george).
-export([start/3, stop/0]).

start(Lock, Sleep, Work) ->
    register(l4, spawn(Lock, init,[4, [{l1,'node1@127.0.0.1'},{l2,'node2@127.0.0.1'},{l3,'node3@127.0.0.1'}]])),
    register(george, spawn(worker, init, ["George",l4,72,Sleep,Work])),
    ok.

stop() ->
    george ! stop,
    l4 ! stop.
