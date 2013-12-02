-module(server2).
-export([start/2]).

start(N, NumRandomEntries) ->
  spawn(fun() -> init(N, NumRandomEntries) end).
init(N, NumRandomEntries) ->
  Store = store:new(N),
  Validator = validator:start(),
  server(Validator, Store, NumRandomEntries).
server(Validator, Store, NumRandomEntries) ->
  receive
    {open, Client} ->
      RandomizedStoreSubset = getRandomSubset(Store, NumRandomEntries),
      Client ! {transaction, Validator, RandomizedStoreSubset},
      server(Validator, Store, NumRandomEntries);
    stop ->
      store:stop(Store)
  end.

getRandomSubset(Tuple, NumRandomEntries) when is_tuple(Tuple) ->
  list_to_tuple(getRandomSubset(tuple_to_list(Tuple), NumRandomEntries));
getRandomSubset(List, NumRandomEntries) when is_list(List) ->
  random:seed(now()),
  lists:sublist(
    [X||{_,X} <- lists:sort([{random:uniform(), Elem} || Elem <- List])],
    NumRandomEntries
  ).
