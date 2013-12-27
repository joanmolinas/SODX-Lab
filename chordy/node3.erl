-module(node3).

-export([start/1, start/2]).

-define(Stabilize, 1000).
-define(Timeout, 5000).

start(MyKey) ->
  start(MyKey, nil).

start(MyKey, PeerPid) ->
  timer:start(),
  register(node3, spawn(fun() -> init(MyKey, PeerPid) end)).

init(MyKey, PeerPid) ->
  Predecessor = nil,
  Next = nil,
  {ok, Successor} = connect(MyKey, PeerPid),
  schedule_stabilize(),
  Store = storage:create(),
  node(MyKey, Predecessor, Successor, Next, Store).

schedule_stabilize() ->
  timer:send_interval(?Stabilize, self(), stabilize).

demonitor_node3(nil) ->
  ok;
demonitor_node3(Node) ->
  {_, _, OldRef} = Node,
  demonit(OldRef).

monitor_node3(Key, Pid) ->
  {Key, Pid, monit(Pid)}.

node(MyKey, Predecessor, Successor, Next, Store) ->
  receive
    {key, Qref, PeerPid} ->
      PeerPid ! {Qref, MyKey},
      node(MyKey, Predecessor, Successor, Next, Store);
    {notify, New} ->
      {{PKey, PPid}, NewStore} = notify(New, MyKey, Predecessor, Store),
      demonitor_node3(Predecessor),
      Pred = monitor_node3(PKey, PPid),
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
      node(MyKey, Predecessor, Successor, Next, Merged);
    {'DOWN', Ref, process, _, _} ->
      {Pred, Succ, Nxt} = down(Ref, Predecessor, Successor, Next),
      node(MyKey, Pred, Succ, Nxt, Store)
  end.

down(Ref, {Pr,_, Ref}, Successor, Next) ->
  io:format("Predecessor ~w Down~n",[Pr]),
  {nil, Successor, Next};
down(Ref, Predecessor, {Sc, _, Ref}, {Nkey, Npid}) ->
  io:format("Successor ~w Down~n",[Sc]),
  self() ! stabilize,
  {Predecessor, monitor_node3(Nkey, Npid), nil}.


request(Peer, Predecessor, {Skey, Spid, _}) ->
  case Predecessor of
    nil ->
      Peer ! {status, nil, {Skey, Spid}};
    {Pkey, Ppid, _} ->
      Peer ! {status, {Pkey, Ppid}, {Skey, Spid}}
  end.

add(Key, Value, Qref, Client, MyKey, {Pkey, _, _}, {_, Spid, _}, Store) ->
  case key:between(Key, Pkey, MyKey) of
    true ->
      Added = storage:add(Key, Value, Store) ,
      Client ! {Qref, ok},
      Added;
    false ->
      Spid ! {add, Key, Value, Qref, Client},
      Store
  end.

lookup(Key, Qref, Client, MyKey, {Pkey, _, _}, {_, Spid, _}, Store) ->
  case key:between(Key, Pkey, MyKey) of
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
    {Pkey, _, _} ->
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
  {Skey, Spid, _} = Successor,
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
          demonitor_node3(Successor),
          {monitor_node3(Xkey, Xpid), {Skey, Spid}};
        false ->
          Spid ! {notify, {MyKey, self()}},
          {Successor, Next}
      end
  end.

stabilize({_, Spid, _}) ->
  Spid ! {request, self()}.

connect(MyKey, nil) ->
  {ok, {MyKey, self(), nil}};
connect(_, PeerPid) ->
  Qref = make_ref(),
  PeerPid ! {key, Qref, self()},
  receive
    {Qref, Skey} ->
      {ok, {Skey, PeerPid, monit(PeerPid)}}
  after ?Timeout ->
    io:format("Timeout: no response from ~w~n", [PeerPid])
  end.

create_probe(MyKey, {_, Spid, _}, Store) ->
  Spid ! {probe, MyKey, [MyKey], erlang:now()},
  io:format("Create probe ~w! Store = ~w ~n", [MyKey, Store]).
remove_probe(MyKey, Nodes, T) ->
  Time = timer:now_diff(erlang:now(), T),
  io:format("Received probe ~w in ~w ms Ring: ~w~n", [MyKey, Time, Nodes]).
forward_probe(RefKey, Nodes, T, {_, Spid, _}, Store) ->
  Spid ! {probe, RefKey, Nodes, T},
  io:format("Forward probe ~w! Store = ~w ~n", [RefKey, Store]).

monit(Pid) ->
  erlang:monitor(process, Pid).
demonit(nil) ->
  ok;
demonit(MonitorRef) ->
  erlang:demonitor(MonitorRef, [flush]).
