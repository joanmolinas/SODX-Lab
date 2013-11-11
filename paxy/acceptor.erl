-module(acceptor).
-export([start/3]).

-define(delay, 50).
-define(sorry, false).
-define(drop_promise, 200000).
-define(drop_votes, 200000).

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
      R = random:uniform(?delay),
      timer:sleep(R),
      case order:gr(Round, Promise) of
        true ->
          case random:uniform(?drop_promise) of
            ?drop_promise ->
              io:format("Promise dropped~n");
            _ ->
              Proposer ! {promise, Round, Voted, Accepted}
            end,

           % Update gui
           if
               Accepted == na ->
                   Colour = {0,0,0};
               true ->
                   Colour = Accepted
           end,
           io:format("[Acceptor ~w] set gui: voted ~w promise ~w colour ~w~n", [Name, Voted, Round, Accepted]),
           PanelId ! {
               updateAcc, "Round voted: " ++ lists:flatten(io_lib:format("~p", [Voted])),
               "Cur. Promise: " ++ lists:flatten(io_lib:format("~p", [Round])),
               Colour
           },
           acceptor(Name, Round, Voted, Accepted, PanelId);
        false ->
          if
            ?sorry ->
              Proposer ! {sorry, {prepare, Voted}};
            true ->
              false
          end,
          acceptor(Name, Promise, Voted, Accepted, PanelId)
      end;

    {accept, Proposer, Round, Proposal} ->
      R = random:uniform(?delay),
      timer:sleep(R),

      case order:goe(Round, Promise) of
           true ->
             case random:uniform(?drop_promise) of
               ?drop_promise ->
                 io:format("Accept dropped~n");
               _ ->
                 Proposer ! {vote, Round}
               end,

               case order:goe(Round, Voted) of
                   true ->
                       % Update gui
                       io:format("[Acceptor ~w] set gui: voted ~w promise ~w colour ~w~n", [Name, Round, Promise, Proposal]),
                       PanelId ! {
                           updateAcc, "Round voted: " ++ lists:flatten(io_lib:format("~p", [Round])),
                           "Cur. Promise: " ++ lists:flatten(io_lib:format("~p", [Promise])),
                           Proposal
                       },
                       acceptor(Name, Promise, Round, Proposal, PanelId);
                   false ->
                       % Update gui
                        io:format("[Acceptor ~w] set gui: voted ~w promise ~w colour ~w~n", [Name, Voted, Promise, Accepted]),
                        PanelId ! {
                            updateAcc, "Round voted: " ++ lists:flatten(io_lib:format("~p", [Round])),
                            "Cur. Promise: " ++ lists:flatten(io_lib:format("~p", [Promise])),
                            Accepted
                        },
                       acceptor(Name, Promise, Voted, Accepted, PanelId)
                   end;
           false ->
               if
                 ?sorry ->
                   Proposer ! {sorry, {accept, Voted}};
                 true ->
                   false
               end,
               acceptor(Name, Promise, Voted, Accepted, PanelId)
       end;
  stop ->
     ok
end.
