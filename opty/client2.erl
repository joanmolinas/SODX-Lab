-module(client2).
-export([start/6]).

start(Name, Entries, ReadUpdates, WriteUpdates, Server, CommitDelay) ->
  spawn(fun() -> open(Name, Entries, ReadUpdates, WriteUpdates, Server, 0, 0, CommitDelay) end).

open(Name, Entries, ReadUpdates, WriteUpdates, Server, Total, Ok, CommitDelay) ->
  {A1, A2, A3} = now(),
  random:seed(A1, A2, A3),
  Server ! {open, self()},
  receive
    {stop, From} ->
      io:format("~w: Transactions TOTAL:~w, OK:~w, -> ~w % ~n", [Name, Total, Ok, 100 * Ok / Total]),
      From ! {done, self()},
      ok;
    {transaction, Validator, Store} ->
      Handler = handler:start(self(), Validator, Store),
      do_transactions(Name, Entries, ReadUpdates, WriteUpdates, Server, Handler, Total, Ok, CommitDelay)
  end.

% Reads and Writes
do_transactions(Name, Entries, ReadUpdates, WriteUpdates, Server, Handler, Total, Ok, CommitDelay) ->
%io:format("~w: R/W: TOTAL ~w, OK ~w, N ~w~n", [Name, Total, Ok, N]),
  ok = do_reads(ReadUpdates, Entries, Handler),
  ok = do_writes(WriteUpdates, Entries, Handler),

  timer:sleep(CommitDelay),
  Ref = make_ref(),
  Handler ! {commit, Ref},
  Result = receiveCommitValue(Ref),
  if
    Result == ok ->
      open(Name, Entries, ReadUpdates, WriteUpdates, Server, Total + 1, Ok + 1, CommitDelay);
    true ->
      open(Name, Entries, ReadUpdates, WriteUpdates, Server, Total + 1, Ok, CommitDelay)
  end.

do_reads(0, _, _)->
  ok;
do_reads(ReadUpdates, Entries, Handler) ->
  Ref = make_ref(),
  Num = random:uniform(Entries),
  Handler ! {read, Ref, Num},
  receiveValue(Ref),
  do_reads(ReadUpdates - 1, Entries, Handler).
do_writes(0, _, _)->
  ok;
do_writes(WriteUpdates, Entries, Handler)->
  Num = random:uniform(Entries),
  Value = random:uniform(100000000),
  Handler ! {write, Num, Value},
  do_writes(WriteUpdates - 1, Entries, Handler).

receiveCommitValue(Ref) ->
  receive
    {Ref, Value} -> Value
  end.

receiveValue(Ref) ->
  receive
    {value, Ref, Value} -> Value
  end.
