-module(john).
-export([start/3, stop/0]).

start(Lock, Sleep, Work) ->
    register(l1, spawn(Lock, init,[1, [{l2,'node2@127.0.0.1'},{l3,'node3@127.0.0.1'},{l4,'node4@127.0.0.1'}]])),
    register(john, spawn(worker, init, ["John", l1,34,Sleep,Work])),
    ok.

stop() ->
    john ! stop,
    l1 ! stop.
