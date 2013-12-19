-module(node3).

-export([start/1, start/2]).

-define(Stabilize, 1000).
-define(Timeout, 5000).

start(MyKey) ->
  start(MyKey, nil).

start(MyKey, PeerPid) ->
  timer:start(),
  register(node2, spawn(fun() -> init(MyKey, PeerPid) end)).

init(MyKey, PeerPid) ->
  Predecessor = nil,
  Next = nil,
  {ok, Successor} = connect(MyKey, PeerPid),
  schedule_stabilize(),
  Store = storage:create(),
  node(MyKey, Predecessor, Successor, Next, Store).

schedule_stabilize() ->
  timer:send_interval(?Stabilize, self(), stabilize).

node(MyKey, Predecessor, Successor, Next, Store) ->
  receive
    {key, Qref, PeerPid} ->
      PeerPid ! {Qref, MyKey},
      node(MyKey, Predecessor, Successor, Next, Store);
    {notify, New} ->
      {Pred, NewStore} = notify(New, MyKey, Predecessor, Store),
      node(MyKey, Pred, Successor, Next, NewStore);
    {request, Peer} ->
        request(Peer, Predecessor, Successor),
        node(MyKey, Predecessor, Successor, Next, Store);
    {status, Pred, Nx} ->

      {Succ, Nxt} = stabilize(Pred, Nx, MyKey, Successor),
      node(MyKey, Predecessor, Succ, Nxt, Store);
    stabilize ->
      stabilize(Successor),
      node(MyKey, Predecessor, Successor, Next, Store);
    probe ->
      create_probe(MyKey, Successor, Store),
      node(MyKey, Predecessor, Successor, Next, Store);
    {probe, MyKey, Nodes, T} ->
      remove_probe(MyKey, Nodes, T),
      node(MyKey, Predecessor, Successor, Next, Store);
    {probe, RefKey, Nodes, T} ->
      forward_probe(RefKey, [MyKey|Nodes], T, Successor, Store),
      node(MyKey, Predecessor, Successor, Next, Store);

    {add, Key, Value, Qref, Client} ->
      Added = add(Key, Value, Qref, Client, MyKey, Predecessor, Successor, Store),
      node(MyKey, Predecessor, Successor, Next, Added);
    {lookup, Key, Qref, Client} ->
      lookup(Key, Qref, Client, MyKey, Predecessor, Successor, Store),
      node(MyKey, Predecessor, Successor, Next, Store);

    {handover, Elements} ->
      Merged = storage:merge(Store, Elements),
      node(MyKey, Predecessor, Successor, Next, Merged)
  end.

request(Peer, Predecessor, {Skey, Spid}) ->
  case Predecessor of
    nil ->
      Peer ! {status, nil, {Skey, Spid}};
    {Pkey, Ppid} ->
      Peer ! {status, {Pkey, Ppid}, {Skey, Spid}}
  end.

add(Key, Value, Qref, Client, MyKey, {Pkey, _}, {_, Spid}, Store) ->
  case key:between(Key, Pkey, MyKey) of
    true ->
      Added = storage:add(Key, Value, Store) ,
      Client ! {Qref, ok},
      Added;
    false ->
      Spid ! {add, Key, Value, Qref, Client},
      Store
  end.

lookup(Key, Qref, Client, MyKey, {Pkey, _}, {_, Spid}, Store) ->
  case key:between(Key, Pkey, MyKey) of %% TODO: ADD SOME CODE
    true ->
      Result = storage:lookup(Key, Store),
      Client ! {Qref, Result};
    false ->
      Spid ! {lookup, Key, Qref, Client}
  end.

notify({Nkey, Npid}, MyKey, Predecessor, Store) ->
  case Predecessor of
    nil ->
      Keep = handover(Store, MyKey, Nkey, Npid),
      {{Nkey, Npid}, Keep};
    {Pkey, _} ->
      case key:between(Nkey, Pkey, MyKey) of
        true ->
          Keep = handover(Store, MyKey, Nkey, Npid),
          {{Nkey, Npid}, Keep};
        false ->
          {Predecessor, Store}
      end
    end.

handover(Store, MyKey, Nkey, Npid) ->
  {Keep, Leave} = storage:split(MyKey, Nkey, Store),
  Npid ! {handover, Leave},
  Keep.

stabilize(Pred, Next, MyKey, Successor) ->
  {Skey, Spid} = Successor,
  case Pred of
    nil ->
      Spid ! {notify, {MyKey, self()}},
      {Successor, Next};
    {MyKey, _} ->
      {Successor, Next};
    {Skey, _} ->
      Spid ! {notify, {MyKey, self()}},
      {Successor, Next};
    {Xkey, Xpid} ->
      case key:between(Xkey, MyKey, Skey) of
        true ->
          self() ! stabilize,
          {{Xkey, Xpid}, Successor};
        false ->
          Spid ! {notify, {MyKey, self()}},
          {Successor, Next}
      end
  end.

stabilize({_, Spid}) ->
  Spid ! {request, self()}.

connect(MyKey, nil) ->
  {ok, {MyKey, self()}};
connect(_, PeerPid) ->
  Qref = make_ref(),
  PeerPid ! {key, Qref, self()},
  receive
    {Qref, Skey} ->
      {ok, {Skey, PeerPid}}
  after ?Timeout ->
    io:format("Timeout: no response from ~w~n", [PeerPid])
  end.

create_probe(MyKey, {_, Spid}, Store) ->
  Spid ! {probe, MyKey, [MyKey], erlang:now()},
  io:format("Create probe ~w! Store = ~w ~n", [MyKey, Store]).
remove_probe(MyKey, Nodes, T) ->
  Time = timer:now_diff(erlang:now(), T),
  io:format("Received probe ~w in ~w ms Ring: ~w~n", [MyKey, Time, Nodes]).
forward_probe(RefKey, Nodes, T, {_, Spid}, Store) ->
  Spid ! {probe, RefKey, Nodes, T},
  io:format("Forward probe ~w! Store = ~w ~n", [RefKey, Store]).
