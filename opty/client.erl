-module(client).
-export([start/5]).

start(Name, Entries, Updates, Server, CommitDelay) ->
  spawn(fun() -> open(Name, Entries, Updates, Server, 0, 0, CommitDelay) end).

open(Name, Entries, Updates, Server, Total, Ok, CommitDelay) ->
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
      do_transactions(Name, Entries, Updates, Server, Handler, Total, Ok, Updates, CommitDelay)
  end.

% Commit transaction
do_transactions(Name, Entries, Updates, Server, Handler, Total, Ok, 0, CommitDelay) ->
  timer:sleep(CommitDelay),
  Ref = make_ref(),
  Handler ! {commit, Ref},
  Result = receiveCommitValue(Ref),
  if
    Result == ok ->
      open(Name, Entries, Updates, Server, Total + 1, Ok + 1, CommitDelay);
    true ->
      open(Name, Entries, Updates, Server, Total + 1, Ok, CommitDelay)
  end;

% Reads and Writes
do_transactions(Name, Entries, Updates, Server, Handler, Total, Ok, N, CommitDelay) ->
%io:format("~w: R/W: TOTAL ~w, OK ~w, N ~w~n", [Name, Total, Ok, N]),
  Ref = make_ref(),
  Num = random:uniform(Entries),
  Handler ! {read, Ref, Num},
  Value = receiveValue(Ref),
  Handler ! {write, Num, Value + 1},
  do_transactions(Name, Entries, Updates, Server, Handler, Total, Ok, N - 1, CommitDelay).

receiveCommitValue(Ref) ->
  receive
    {Ref, Value} -> Value
  end.

receiveValue(Ref) ->
  receive
    {value, Ref, Value} -> Value
  end.
