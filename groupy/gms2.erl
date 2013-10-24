-module(gms2).
-export([start/1, start/2]).

-define(arghh, 100).

start(Id) ->
  Rnd = random:uniform(1000),
  Self = self(),
  spawn_link(fun()-> init(Id, Rnd, Self) end).

init(Id, Rnd, Master) ->
  random:seed(Rnd, Rnd, Rnd),
  leader(Id, Master, []).


start(Id, Grp) ->
  Rnd = random:uniform(1000),
  Self = self(),
  spawn_link(fun() -> init(Id, Grp, Rnd, Self) end).

init(Id, Grp, Rnd, Master) ->
  random:seed(Rnd, Rnd, Rnd),
  Self = self(),
  Grp ! {join, Self},
  receive
    {view, State, Leader, Peers} ->
      erlang:monitor(process, Leader),
      Master ! {ok, State},
      slave(Id, Master, Leader, Peers)
    after 1000 ->
      Master ! {error, "no reply from leader"}
  end.


leader(Id, Master, Peers) ->
  receive
    {mcast, Msg} ->
      bcast(Id, {msg, Msg}, Peers),
      Master ! {deliver, Msg},
      leader(Id, Master, Peers);
    {join, Peer} ->
      Master ! request,
      joining(Id, Master, Peer, Peers);
    stop ->
      ok;
    Error ->
      io:format("leader ~w: strange message ~w~n", [Id, Error])
  end.

bcast(Id, Msg, Nodes) ->
  lists:foreach(
    fun(Node) ->
      Node ! Msg,
      crash(Id)
    end,
    Nodes
  ).

crash(Id) ->
  case random:uniform(?arghh) of
    ?arghh ->
      io:format("leader ~w: crash~n", [Id]),
      exit(no_luck);
    _ ->
      ok
  end.

joining(Id, Master, Peer, Peers) ->
  receive
    {ok, State} ->
      Peers2 = lists:append(Peers, [Peer]),
      bcast(Id, {view, State, self(), Peers2}, Peers2),
      leader(Id, Master, Peers2);
    stop ->
      ok
  end.

slave(Id, Master, Leader, Peers) ->
  receive
    {mcast, Msg} ->
      Leader ! {mcast, Msg},
      slave(Id, Master, Leader, Peers);
    {join, Peer} ->
      Leader ! {join, Peer},
      slave(Id, Master, Leader, Peers);
    {msg, Msg} ->
      Master ! {deliver, Msg},
      slave(Id, Master, Leader, Peers);
    {view, _, _, View} ->
      slave(Id, Master, Leader, View);
    {'DOWN', _Ref, process, Leader, _Reason} ->
      election(Id, Master, Peers);
    stop ->
      ok;
    Error ->
      io:format("slave ~w: strange message ~w~n", [Id, Error])
  end.

election(Id, Master, [Leader|Rest]) ->
  if
    Leader == self() ->
      leader(Id, Master, Rest);
    true ->
      erlang:monitor(process, Leader),
      slave(Id, Master, Leader, Rest)
  end.
