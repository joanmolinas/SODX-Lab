-module(opty2).
-export([startServer/6, startClients/0]).

startServer(Clients, Entries, Updates, Time, CommitDelay, ClientSpawnerProcess)->
  ClientSpawnerProcess ! {server, server:start(Entries), Clients, Entries, Updates, Time, CommitDelay}.


%% Clients: Number of concurrent clients in the system
%% Entries: Number of entries in the store
%% Updates: Number of write operations per transaction
%% Time: Duration of the experiment (in secs)
startClients() ->
  register(client_spawner_process, self()),
  receive
    {server, Server, Clients, Entries, Updates, Time, CommitDelay} ->
      L = startClients(Clients, [], Entries, Updates, Server, CommitDelay),
      io:format(
        "Starting: ~w CLIENTS, ~w ENTRIES, ~w UPDATES PER TRANSACTION,~nDURATION ~w s ~n",
        [Clients, Entries, Updates, Time]
      ),
      timer:sleep(Time * 1000),
      stop(L, Server)
  end.

stop(L, Server) ->
  io:format("Stopping...~n"),
  stopClients(L),
  Server ! stop.

startClients(0, L, _, _, _, _) ->
  L;
startClients(Clients, L, Entries, Updates, Server, CommitDelay) ->
  Pid = client:start(Clients, Entries, Updates, Server, CommitDelay),
  startClients(Clients - 1, [Pid|L], Entries, Updates, Server, CommitDelay).

stopClients([]) -> ok;
stopClients([Pid|L]) ->
  Pid ! {stop, self()},
  receive
    {done, Pid} -> ok
  end,
  stopClients(L).
