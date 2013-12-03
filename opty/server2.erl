-module(server2).
-export([start/2]).

start(N, NumRandomEntries) ->
  spawn(fun() -> init(N, NumRandomEntries) end).
init(N, NumRandomEntries) ->
  Store = store:new(N),
  Validator = validator:start(),
  server(Validator, Store, NumRandomEntries, N).
server(Validator, Store, NumRandomEntries, StoreSize) ->
  receive
    {open, Client} ->
      RandomizedStoreSubset = getRandomSubset(Store, NumRandomEntries, StoreSize),
      Client ! {transaction, Validator, RandomizedStoreSubset},
      server(Validator, Store, NumRandomEntries, StoreSize);
    stop ->
      store:stop(Store)
  end.

getRandomSubset(Tuple, StoreSize, StoreSize) ->
  Tuple;
getRandomSubset(Tuple, NumRandomEntries, StoreSize) when is_tuple(Tuple) ->
  list_to_tuple(getRandomSubset(tuple_to_list(Tuple), NumRandomEntries, StoreSize));
getRandomSubset(List, NumRandomEntries, StoreSize) when is_list(List) ->
  Start = random:uniform(StoreSize - NumRandomEntries),
  lists:sublist(List, Start, NumRandomEntries).
