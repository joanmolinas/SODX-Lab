-module(proposer).
-export([start/5]).
-define(timeout, 2000).
-define(backoff, 10).
start(Name, Proposal, Acceptors, Seed, PanelId) ->
    spawn(fun() -> init(Name, Proposal, Acceptors, Seed, PanelId) end).
init(Name, Proposal, Acceptors, Seed, PanelId) ->
    random:seed(Seed, Seed, Seed),
    Round = order:null(Name),
    round(Name, ?backoff, Round, Proposal, Acceptors, PanelId).
round(Name, Backoff, Round, Proposal, Acceptors, PanelId) ->
    % Update gui
    io:format("[Proposer ~w - Round] set gui: Round ~w Proposal ~w~n", [Name, Round, Proposal]),
    PanelId ! {
        updateProp, "Round: " ++ lists:flatten(io_lib:format("~p", [Round])),
        "Proposal: " ++ lists:flatten(io_lib:format("~p", [Proposal])),
        Proposal
    },
    case ballot(Name, Round, Proposal, Acceptors, PanelId) of
        {ok, Decision} ->
            io:format("[Proposer ~w  - After Ballot] ~w decided ~w in round ~w~n",
            [Name, Acceptors, Decision, Round]),
            {ok, Decision};
        abort ->
          timer:sleep(random:uniform(Backoff)),
          Next = order:inc(Round),
          round(Name, (2*Backoff), Next, Proposal, Acceptors, PanelId)
    end.

ballot(Name, Round, Proposal, Acceptors, PanelId) ->
    prepare(Round,Acceptors),
    Quorum = (length(Acceptors) div 2) + 1,
    Sorries = Quorum,  %we know in some cases this isn't completely true, but that's life
    Max = order:null(),
    case collect(Quorum, Round, Max, Proposal, Sorries) of
        {accepted, Value} ->
            % update gui
            io:format("[Proposer ~w  - Collected] set gui: Round ~w Proposal ~w~n", [Name, Round, Value]),
            PanelId ! {
                updateProp,
                "Round: " ++ lists:flatten(io_lib:format("~p", [Round])),
                "Proposal: " ++ lists:flatten(io_lib:format("~p", [Value])),
                Value
            },
            accept(Round, Value, Acceptors),
            case vote(Quorum, Round, Sorries) of
                ok ->
                    {ok, Value};
                abort ->
                    abort
            end;
        abort ->
            abort
    end.

collect(_N, _Round, _Max, _Proposal, 0) ->
  abort;
collect(0, _Round, _Max, Proposal, _Sorries) ->
    {accepted, Proposal};
collect(N, Round, Max, Proposal, Sorries) ->
    receive
        {promise, Round, _, na} ->
            collect(N - 1, Round, Max, Proposal, Sorries);
        {promise, Round, Voted, Value} ->
            case order:gr(Voted, Max) of
                true ->
                    collect(N - 1, Round, Voted, Value, Sorries);
                false ->
                    collect(N - 1, Round, Max, Proposal, Sorries)
            end;
        {promise, _, _, _} ->
            collect(N, Round, Max, Proposal, Sorries);
        {sorry, {prepare, Round}} ->
            collect(N, Round, Max, Proposal, Sorries - 1);
        {sorry, _} ->
            collect(N, Round, Max, Proposal, Sorries)
    after ?timeout ->
            abort
    end.

vote(_N, _Round, 0) ->
  abort;
vote(0, _Round, _Sorries) ->
  ok;
vote(N, Round, Sorries) ->
  receive
    {vote, Round} ->
      vote(N - 1, Round, Sorries);
    {vote, _} ->
      vote(N, Round, Sorries);
    {sorry, {accept, Round}} ->
      vote(N, Round, Sorries - 1);
    {sorry, _} ->
      vote(N, Round, Sorries)
  after ?timeout ->
    abort
  end.

prepare(Round, Acceptors) ->
    Fun = fun(Acceptor) ->
        send(Acceptor, {prepare, self(), Round})
    end,
    lists:map(Fun, Acceptors).

accept(Round, Proposal, Acceptors) ->
  Fun = fun(Acceptor) ->
    send(Acceptor, {accept, self(), Round, Proposal})
  end,
  lists:map(Fun, Acceptors).

send(Name, Message) ->
    case whereis(Name) of
      undefined ->
        down;
      Pid ->
        Pid ! Message
    end.
