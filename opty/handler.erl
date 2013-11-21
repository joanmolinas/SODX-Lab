-module(handler).

-export([start/3]).

start(Client, Validator, Store) ->
  spawn_link(fun() -> init(Client, Validator, Store) end).

init(Client, Validator, Store) ->
  handler(Client, Validator, Store, [], []).

handler(Client, Validator, Store, Reads, Writes) ->
  receive
    {read, Ref, N} ->
      case lists:keyfind(N, 1, Writes) of
        {N, _, Value} ->
          Client ! {value, Ref, Value},
          handler(Client, Validator, Store, Reads, Writes);
        false ->
          N ! {read, Ref, self()},
          handler(Client, Validator, Store, Reads, Writes)
      end;
    {Ref, Entry, Value, Time} ->
      Client ! {read, Ref, Value},
      handler(Client, Validator, Store, [{Entry, Time}|Reads], Writes);
    {write, N, Value} ->
      %% TODO: ADD SOME CODE HERE AND COMPLETE NEXT LINE

      Added = lists:keystore(N, 1, Writes, {N, ..., Value}),
      handler(Client, Validator, Store, Reads, Added);
    {commit, Ref} ->
      Validator ! {validate, Ref, Reads, Writes, Client};
    abort ->
      ok
  end.