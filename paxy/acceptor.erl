-module(acceptor).
-export([start/3]).
start(Name, Seed, PanelId) ->
    spawn(fun() -> init(Name, Seed, PanelId) end).
init(Name, Seed, PanelId) ->
    random:seed(Seed, Seed, Seed),
    Promise = order:null(),
    Voted = order:null(),
    Accepted = na,
    acceptor(Name, Promise, Voted, Accepted, PanelId).

acceptor(Name, Promise, Voted, Accepted, PanelId) ->
  receive
   {prepare, Proposer, Round} ->
       case order:gr(..., ...) of
           true ->
               ... ! {promise, ..., ..., ...},
               % Update gui
               if
                   Accepted == na ->
                       Colour = {0,0,0};
                   true ->
                       Colour = Accepted
               end,
   io:format("[Acceptor ~w] set gui: voted ~w promise ~w colour ~w~n",
                       [Name, ..., ..., Accepted]),
                       PanelId ! {updateAcc, "Round voted: "
   ++ lists:flatten(io_lib:format("~p", [Voted])), "Cur. Promise: "
   ++ lists:flatten(io_lib:format("~p", [...])), Colour},
               acceptor(Name, ..., Voted, Accepted, PanelId);
           false ->
               ... ! {sorry, {prepare, ...}},
               acceptor(Name, ..., Voted, Accepted, PanelId)
       end;

 {accept, Proposer, Round, Proposal} ->
     case order:goe(..., ...) of
         true ->
             ... ! {vote, ...},
             case order:goe(..., ...) of
                 true ->
                  % Update gui
io:format("[Acceptor ~w] set gui: voted ~w promise ~w colour ~w~n",
                     [Name, ..., ..., ...]),
                     PanelId ! {updateAcc, "Round voted: "
++ lists:flatten(io_lib:format("~p", [...])), "Cur. Promise: "
++ lists:flatten(io_lib:format("~p", [Promise])), ...},
                     acceptor(Name, Promise, ..., ..., PanelId);
                 false ->
                     % Update gui
io:format("[Acceptor ~w] set gui: voted ~w promise ~w colour ~w~n",
                     [Name, ..., ..., ...]),
                     PanelId ! {updateAcc, "Round voted: "
++ lists:flatten(io_lib:format("~p", [...])), "Cur. Promise: "
++ lists:flatten(io_lib:format("~p", [Promise])), ...},
                     acceptor(Name, Promise, ..., ..., PanelId)
             end;
         false ->
             ... ! {sorry, {accept, ...}},
             acceptor(Name, Promise, ..., ..., PanelId)
     end;

  stop ->
     ok
end.


