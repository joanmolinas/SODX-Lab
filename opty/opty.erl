-module(opty).
-export([start/5, start/6, stop/1]).

%% Clients: Number of concurrent clients in the system
%% Entries: Number of entries in the store
%% Updates: Number of write operations per transaction
%% Time: Duration of the experiment (in secs)
start(Clients, Entries, Updates, Time, CommitDelay) ->
  start(Clients, Entries, Updates, Updates, Time, CommitDelay).

start(Clients, Entries, ReadUpdates, WriteUpdates, Time, CommitDelay) ->
  register(s, server:start(Entries)),
  L = startClients(Clients, [], Entries, ReadUpdates, WriteUpdates, CommitDelay),
  io:format(
    "Starting: ~w CLIENTS, ~w ENTRIES, ~w READ UPDATES PER TRANSACTION, ~w WRITE UPDATES PER TRANSACTION,~nDURATION ~w s ~n",
    [Clients, Entries, ReadUpdates, WriteUpdates, Time]),
  timer:sleep(Time * 1000),
  stop(L).

stop(L) ->
  io:format("Stopping...~n"),
  stopClients(L),
  s ! stop.

startClients(0, L, _, _, _, _) ->
  L;
startClients(Clients, L, Entries, ReadUpdates, WriteUpdates, CommitDelay) ->
  Pid = client2:start(Clients, Entries, ReadUpdates, WriteUpdates, s, CommitDelay),
  startClients(Clients - 1, [Pid|L], Entries, ReadUpdates, WriteUpdates, CommitDelay).

stopClients([]) -> ok;
stopClients([Pid|L]) ->
  Pid ! {stop, self()},
  receive
    {done, Pid} -> ok
  end,
  stopClients(L).
