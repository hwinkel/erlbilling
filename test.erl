-module(test).
-author('Michael Filonenko').
-export([test/0, init/0, test/1, test_under_timer/1, test_under_timer/2]).
-include("billingserver.hrl").  % .hrl file generated by erlsom

test_avg(M, F, A, N) when N > 0 ->
    L = test_loop(M, F, A, N, []),
    Length = length(L),
    Min = lists:min(L),
    Max = lists:max(L),
    Med = lists:nth(round((Length / 2)), lists:sort(L)),
    Avg = round(lists:foldl(fun(X, Sum) -> X + Sum end, 0, L) / Length),
    io:format("Range: ~b - ~b mics~n"
	      "Median: ~b mics~n"
	      "Average: ~b mics~n",
	      [Min, Max, Med, Avg]),
    Med.

test_loop(_M, _F, _A, 0, List) ->
    List;
test_loop(M, F, A, N, List) ->
    {T, _Result} = timer:tc(M, F, A),
    test_loop(M, F, A, N - 1, [T|List]).

% insert transaction
init() ->
    code:add_path("./deps/yaws/ebin"),
    inets:start(),
    Wsdl = yaws_soap_lib:initModel("http://localhost:8081/billingserver.wsdl"),
    Wsdl.

iter(_, 0) ->
    0
        ;
iter(Wsdl, Count) ->
                                                %io:format("-----------------\nAccount: ~w\n", [Count]),
    {ok, _, [#'p:RefillAmountResponse'{'Result' = RefillResult}]} = yaws_soap_lib:call(Wsdl, "RefillAmount", [Count, random:uniform((2 bsl 16) - 1)]),
    {ok, _, [#'p:RefillAmountResponse'{'Result' = RefillResult2}]} = yaws_soap_lib:call(Wsdl, "RefillAmount", [Count, 54545]),
                                                %io:format("~w\n", [list_to_atom(RefillResult)]),
                                                %    {ok, _, [#'p:ChargeAmountResponse'{'Result' = ChargeResult}]} = yaws_soap_lib:call(Wsdl, "ChargeAmount", [Count, random:uniform((2 bsl 16) - 1)]),
                                                %io:format("Charge amount: ~w\n", [list_to_atom(ChargeResult)]),
    {ok,_,
     [#'p:ReserveAmountResponse'{'Result' = TransactionIdStr}]} = yaws_soap_lib:call(Wsdl, "ReserveAmount", [Count, 
                                                %random:uniform((2 bsl 16) - 1)
                                                                                                             10
                                                                                                            ]),
                                                %io:format("~s\n", [TransactionIdStr]),
    
    case list_to_atom(TransactionIdStr) of
        e_insufficientcredit ->
            error;
        e_invalidaccount ->
            error;
        e_internalerror ->
            error;
        _ ->
            case random:uniform(3) of
                3 ->
                    break;
                2 ->
                    {ok, _, [#'p:ConfirmTransactionResponse'{'Result' = Result}]} = yaws_soap_lib:call(Wsdl, "ConfirmTransaction", [TransactionIdStr])
                                                %, io:format("Confirm result: ~w\n", [list_to_atom(Result)])
                        ;
                1 ->
                    {ok, _, [#'p:CancelTransactionResponse'{'Result' = Result}]} = yaws_soap_lib:call(Wsdl, "CancelTransaction", [TransactionIdStr])
                                                %, io:format("Cancel result: ~w\n", [list_to_atom(Result)])
            end
    end,
    
    iter(Wsdl, Count - 1)
        .

test() ->
    iter(init(), random:uniform(100)).

test(Count) ->
    iter(init(), Count).

test_under_timer(TransactionCount, TestCount) ->
    test_avg(test, test, [TransactionCount], TestCount).

test_under_timer(TestCount) ->
    test_avg(test, test, [], TestCount).