-module(lock3).
-export([init/2]).

init(Id, Nodes) ->
    open(Id, Nodes, 0).
open(Id, Nodes, Time) ->
    receive
        {take, Master} ->
            Refs = requests(Id, Nodes, Time),
            wait(Id, Nodes, Master, Refs, [], Time, Time);
        {request, From, _, Ref, SenderTime} ->
            CurrentTime = calculate_time(Time, SenderTime),
            From ! {ok, Ref, CurrentTime},
            open(Id, Nodes, CurrentTime);
        stop ->
            ok
    end.


requests(Id, Nodes, Time) ->
    lists:map(
        fun(P) ->
            R = make_ref(),
            P ! {request, self(), Id, R, Time},
            R
        end,
        Nodes).

wait(Id, Nodes, Master, [], Waiting, Time, _) ->
    Master ! taken,
    held(Id, Nodes, Waiting, Time);

wait(Id, Nodes, Master, Refs, Waiting, Time, RequestSentTime) ->
    receive
        {request, From, _, Ref, SenderTime} ->
            CurrentTime = calculate_time(Time, SenderTime),
            if
                SenderTime < RequestSentTime ->
                    From ! {ok, Ref, CurrentTime},
                    Refs2 = requests(Id, [From], CurrentTime),
                    wait(Id, Nodes, Master, lists:merge(Refs, Refs2), Waiting, CurrentTime, RequestSentTime);
                true ->
                    wait(Id, Nodes, Master, Refs, [{From, Ref}|Waiting], CurrentTime, RequestSentTime)
            end;
        {ok, Ref, SenderTime} ->
            CurrentTime = calculate_time(Time, SenderTime),
            Refs2 = lists:delete(Ref, Refs),
            wait(Id, Nodes, Master, Refs2, Waiting, CurrentTime, RequestSentTime);
        release ->
            ok(Waiting, Time),
            open(Id, Nodes, Time)
    end.

ok(Waiting, Time) ->
    lists:map(
        fun({F,R}) ->
            F ! {ok, R, Time}
        end,
        Waiting).

held(Id, Nodes, Waiting, Time) ->
    receive
        {request, From, _, Ref, SenderTime} ->
            CurrentTime = calculate_time(Time, SenderTime),
            held(Id, Nodes, [{From, Ref}|Waiting], CurrentTime);
        release ->
            ok(Waiting, Time),
            open(Id, Nodes, Time)
    end.

calculate_time(Time, SenderTime) -> lists:max([Time, SenderTime]) + 1.
