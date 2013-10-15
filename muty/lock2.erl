-module(lock2).
-export([init/2]).

init(Id, Nodes) ->
    open(Id, Nodes).
open(Id, Nodes) ->
    receive
        {take, Master} ->
            Refs = requests(Id, Nodes),
            wait(Id, Nodes, Master, Refs, []);
        {request, From, FromId, Ref} ->
            From ! {ok, Ref},
            open(Id, Nodes);
        stop ->
            ok
    end.

requests(Id, Nodes) ->
    lists:map(
        fun(P) ->
            R = make_ref(),
            P ! {request, self(), Id, R},
            R
        end,
        Nodes).

wait(Id, Nodes, Master, [], Waiting) ->
    Master ! taken,
    held(Id, Nodes, Waiting);

wait(Id, Nodes, Master, Refs, Waiting) ->
    receive
        {request, From, FromId, Ref} ->
            if
                FromId < Id ->
                    From ! {ok, Ref};
                    Refs2 = requests(Id, [From])
                    wait(Nodes, Master, lists:merge(Refs, Refs2), Waiting);
                true ->
                    wait(Id, Nodes, Master, Refs, [{From, Ref}|Waiting]);
            end
        {ok, Ref} ->
            Refs2 = lists:delete(Ref, Refs),
            wait(Nodes, Master, Refs2, Waiting);
        release ->
            ok(Waiting),
            open(Nodes)
    end.

ok(Waiting) ->
    lists:map(
        fun({F,R}) ->
            F ! {ok, R}
        end,
        Waiting).

held(Id, Nodes, Waiting) ->
    receive
        {request, From, FromId, Ref} ->
            held(Id, Nodes, [{From, Ref}|Waiting]);
        release ->
            ok(Waiting),
            open(Id, Nodes)
    end.
