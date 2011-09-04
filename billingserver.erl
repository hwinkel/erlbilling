-module(billingserver).
-author('Michael Filonenko').
-include("tables.hrl").

-behaviour(gen_server).

-export([start/0, start/1, stop/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-export([
         add_account/1, retreive_account/1, remove_account/1, account_list/0,
         
         transaction_list/0, unfinished_transaction_list/1,
         finished_transaction_list/1, 

         refill_amount/2,
         reserve_amount/2, charge_amount/2,
         confirm_transaction/1, cancel_transaction/1]).

-record(state, {}).
-define(SERVER, ?MODULE).

%%====================================================================
%% API
%%====================================================================
%%--------------------------------------------------------------------
%% Function: start() -> {ok,Pid} | ignore | {error,Error}
%% Description: Starts the server
%%--------------------------------------------------------------------
start() ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).
start(init) ->
  gen_server:start_link({local, ?SERVER}, ?MODULE, [init], []).

%%====================================================================
%% API
%%====================================================================
%%--------------------------------------------------------------------
%% Function: start() -> ok
%% Description: Stop the server
%%--------------------------------------------------------------------
stop() ->
    gen_server:cast(billingserver, stop).

%%====================================================================
%% gen_server callbacks
%%====================================================================

%%--------------------------------------------------------------------
%% Function: init(Args) -> {ok, State} |
%%                         {ok, State, Timeout} |
%%                         ignore               |
%%                         {stop, Reason}
%% Description: Initiates the server
%%--------------------------------------------------------------------
init([]) ->
    bs_start(),
    {ok, #state{}};
init([init]) ->
    bs_start(init),
    {ok, #state{}}.

%%--------------------------------------------------------------------
%% Function: %% handle_call(Request, From, State) -> {reply, Reply, State} |
%%                                      {reply, Reply, State, Timeout} |
%%                                      {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, Reply, State} |
%%                                      {stop, Reason, State}
%% Description: Handling call messages
%%--------------------------------------------------------------------
handle_call({add_account, AccountNumber}, _From, State) ->
  Reply = bs_add_account(AccountNumber),
  {reply, Reply, State};
handle_call({retreive_account, AccountNumber}, _From, State) ->
  Reply = bs_retreive_account(AccountNumber),
  {reply, Reply, State};
handle_call({remove_account, AccountNumber}, _From, State) ->
  Reply = bs_remove_account(AccountNumber),
  {reply, Reply, State};
handle_call({refill_amount, AccountNumber, Amount}, _From, State) ->
  Reply = bs_refill_amount(AccountNumber, Amount),
  {reply, Reply, State};
handle_call({charge_amount, AccountNumber, Amount}, _From, State) ->
  Reply = bs_charge_amount(AccountNumber, Amount),
  {reply, Reply, State};
handle_call({reserve_amount, AccountNumber, Amount}, _From, State) ->
  Reply = bs_reserve_amount(AccountNumber, Amount),
  {reply, Reply, State};
handle_call({confirm_transaction, TransactionId}, _From, State) ->
  Reply = bs_confirm_transaction(TransactionId),
  {reply, Reply, State};
handle_call({cancel_transaction, TransactionId}, _From, State) ->
  Reply = bs_cancel_transaction(TransactionId),
  {reply, Reply, State};
handle_call({account_list}, _From, State) ->
  Reply = bs_account_list(),
  {reply, Reply, State};
handle_call({transaction_list}, _From, State) ->
  Reply = bs_transaction_list(),
  {reply, Reply, State};
handle_call({unfinished_transaction_list, AccountNumber}, _From, State) ->
  Reply = bs_unfinished_transaction_list(AccountNumber),
  {reply, Reply, State};
handle_call({finished_transaction_list, AccountNumber}, _From, State) ->
  Reply = bs_finished_transaction_list(AccountNumber),
  {reply, Reply, State};
handle_call(_Request, _From, State) ->
  Reply = ok,
  {reply, Reply, State}.



%%--------------------------------------------------------------------
%% Function: handle_cast(Msg, State) -> {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, State}
%% Description: Handling cast messages
%%--------------------------------------------------------------------
handle_cast(stop, State) ->
    {stop, normal, State};
handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% Function: handle_info(Info, State) -> {noreply, State} |
%%                                       {noreply, State, Timeout} |
%%                                       {stop, Reason, State}
%% Description: Handling all non call/cast messages
%%--------------------------------------------------------------------
handle_info(_Info, State) ->
  {noreply, State}.

%%--------------------------------------------------------------------
%% Function: terminate(Reason, State) -> void()
%% Description: This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any necessary
%% cleaning up. When it returns, the gen_server terminates with Reason.
%% The return value is ignored.
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    bs_stop(),
    ok.

%%--------------------------------------------------------------------
%% Func: code_change(OldVsn, State, Extra) -> {ok, NewState}
%% Description: Convert process state when code is changed
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

add_account(AccountNumber) ->
  gen_server:call(?SERVER, {add_account, AccountNumber}).
retreive_account(AccountNumber) ->
  gen_server:call(?SERVER, {retreive_account, AccountNumber}).
remove_account(AccountNumber) ->
  gen_server:call(?SERVER, {remove_account, AccountNumber}).
refill_amount(AccountNumber, Amount) ->
  gen_server:call(?SERVER, {refill_amount, AccountNumber, Amount}).
charge_amount(AccountNumber, Amount) ->
  gen_server:call(?SERVER, {charge_amount, AccountNumber, Amount}).
reserve_amount(AccountNumber, Amount) ->
  gen_server:call(?SERVER, {reserve_amount, AccountNumber, Amount}).
confirm_transaction(TransactionId) ->
  gen_server:call(?SERVER, {confirm_transaction, TransactionId}).
cancel_transaction(TransactionId) ->
  gen_server:call(?SERVER, {cancel_transaction, TransactionId}).
account_list() ->
  gen_server:call(?SERVER, {account_list}).
transaction_list() ->
  gen_server:call(?SERVER, {transaction_list}).
unfinished_transaction_list(AccountNumber) ->
  gen_server:call(?SERVER, {unfinished_transaction_list, AccountNumber}).
finished_transaction_list(AccountNumber) ->
  gen_server:call(?SERVER, {finished_transaction_list, AccountNumber}).


%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------

% utils
% metaprogramming
%eval(S,Environ) ->
%    {ok,Scanned,_} = erl_scan:string(S),
%    {ok,Parsed} = erl_parse:parse_exprs(Scanned),
%    erl_eval:exprs(Parsed,Environ).

bs_add_account(AccountNumber) ->
    Account = #account{accountnumber=AccountNumber, balance=0},
    InsertFun = fun() ->
                        case mnesia:read({account, AccountNumber}) of
                            [_] ->
                                mnesia:abort(e_accountexists);
                            _ ->
                                mnesia:write(Account)
                        end
                end,
    case mnesia:transaction(InsertFun) of
        {atomic, Result} ->
            Result;
        {aborted, Reason} ->
            if Reason == e_accountexists ->
                    Reason;
               true ->
                    e_internalerror
            end
    end.

bs_retreive_account(AccountNumber) ->
    RetrFun = fun() ->
                      mnesia:read({account, AccountNumber})
              end,
    mnesia:transaction(RetrFun).

bs_remove_account(AccountNumber) ->
    DeleteFun = fun() ->
                        mnesia:delete({account, AccountNumber}),
                        MatchHead = #transaction{transactionid='$1', accountnumber='$2',
                                                 _='_'},
                        GuardDel = {'==', '$2', AccountNumber},
                        Result = '$_',
                        ListsDel = mnesia:select(transaction,[{MatchHead, [GuardDel],
                                                               [Result]}]),
                        lists:foreach(fun(List) -> mnesia:delete_object(List) end, ListsDel)
                end,
    mnesia:activity(async_dirty, DeleteFun).

% При коллизии uuid-а транзакция не производится.
add_transaction(AccountNumber, Amount, Finished) ->
    Transaction = #transaction{transactionid = uuid:uuid4(), accountnumber = AccountNumber, amount = Amount, finished = Finished},
    AddTranFun = fun() ->
                         case mnesia:wread({transaction, Transaction#transaction.transactionid}) of
                             [_] ->
                                 mnesia:abort(e_transactionexists);
                             _ ->
                                 case mnesia:wread({account, AccountNumber}) of
                                     [Acc] ->
                                         Balance = Amount + Acc#account.balance,
                                         if Balance < 0 ->
                                                % "Not enough money"
                                                 mnesia:abort(e_insufficientcredit);
                                            true ->
                                                 Acc2 = Acc#account{balance = Balance},
                                                 mnesia:write(Acc2),
                                                 mnesia:write(Transaction)
                                         end;
                                     _ ->
                                                %"No such account"
                                         mnesia:abort(e_invalidaccount)
                                 end
                         end
                 end,
    case mnesia:transaction(AddTranFun) of
        {atomic, _} ->
            Transaction#transaction.transactionid;
        {aborted, Reason} ->
            if Reason == e_invalidaccount ;
               Reason == e_insufficientcredit ->
                    Reason;
               true ->
                    e_internalerror
            end
    end.

bs_refill_amount(AccountNumber, Amount) ->
    add_transaction(AccountNumber, Amount, true).

bs_reserve_amount(AccountNumber, Amount) ->
    add_transaction(AccountNumber, -Amount, false).

bs_charge_amount(AccountNumber, Amount) ->
    add_transaction(AccountNumber, -Amount, true).

bs_confirm_transaction(TransactionId) ->
    ConfTranFun = fun() ->
                         case mnesia:wread({transaction, TransactionId}) of
                             [Transaction] ->
                                 Finished = Transaction#transaction.finished,
                                 case Finished
                                 of true ->
                                                % "Wrong transaction status"
                                         mnesia:abort(e_wrongtransactionstatus);
                                    false ->
                                         Transaction2 = Transaction#transaction{finished = true},
                                         mnesia:write(Transaction2)
                                 end;
                             _ ->
                                                %"No such account"
                                 mnesia:abort(e_transactionnotfound)
                         end
                  end,
    case mnesia:transaction(ConfTranFun) of
        {atomic, _} ->
            e_success;
        {aborted, Reason} ->
            if Reason == e_transactionnotfound ;
               Reason == e_wrongtransactionstatus ->
                    Reason;
               true ->
                    e_internalerror
            end
    end.

bs_cancel_transaction(TransactionId) ->
    CancTranFun = fun() ->
                          case mnesia:wread({transaction, TransactionId}) of
                              [Transaction] ->
                                  Finished = Transaction#transaction.finished,
                                  case Finished
                                  of false ->
                                          case mnesia:wread({account, Transaction#transaction.accountnumber}) of
                                              [Acc] ->
                                                % because we store negative value for outgoing transaction
                                                  Balance =  Acc#account.balance - Transaction#transaction.amount,
                                                  if Balance < 0 ->
                                                % "Not enough money"
                                                          mnesia:abort(e_insufficientcredit);
                                                     true ->
                                                          Acc2 = Acc#account{balance = Balance},
                                                          mnesia:write(Acc2)
                                                  end;
                                              _ ->
                                                %"No such account"
                                                  mnesia:abort(e_invalidaccount)
                                          end,
                                          mnesia:delete({transaction, Transaction#transaction.transactionid});
                                      true ->
                                                % "Wrong transaction status"
                                          mnesia:abort(e_wrongtransactionstatus)
                                              
                                  end;
                              _ ->
                                                %"No such account"
                                  mnesia:abort(e_transactionnotfound)
                          end
                  end,
    case mnesia:transaction(CancTranFun) of
        {atomic, _} ->
            e_success;
        {aborted, Reason} ->
            if Reason == e_wrongtransactionstatus ;
               Reason == e_transactionnotfound ->
                    Reason;
               true ->
                    e_internalerror
            end
    end.
 
deinit() ->
    mnesia:delete_schema([node()]).

init_tables() ->
    case mnesia:create_table(account,
                             [{disc_copies, [node()]},
                              {attributes, record_info(fields,account)}])
    of {atomic, ok} ->
            case mnesia:create_table(transaction,
                                     [{disc_copies, [node()]},
                                      {attributes, record_info(fields,transaction)}])
            of
                {atomic, ok} ->
                    success;
                {aborted, Reason} ->
                    {error, Reason}
            end;
        {aborted, Reason} ->
            {error, Reason}
    end.


mnesia_init_env() ->
    application:set_env(mnesia, dump_log_write_threshold, 60000),
    application:set_env(mnesia, dc_dump_limit, 40).

initschema() ->
    mnesia:create_schema([node()]),
    mnesia:change_config(extra_db_nodes, [node()]),
    mnesia:start(),
    case init_tables() of
        {error, Reason} ->
            io:format("Could not create tables. Reason: ~w", [Reason]);
        success ->
            io:format("Tables are created.", [])
    end.

bs_start(all) ->
    compile:file(uuid),
    compile:file(soapbilling),
    code:load_file(uuid),
    code:load_file(soapbilling),
    code:add_path("./deps/erlsom/ebin"),
    code:add_path("./deps/yaws/ebin"),
    Docroot = "www",
    Logdir = "log",
    Tmpdir = "tmp",
    yaws:start_embedded(Docroot,[{port,8081},
                                 {servername,"localhost"},
                                 {dir_listings, true},
                                 {listen,{0,0,0,0}},
                                 {flags,[{auth_log,false},{access_log,false}]}],
                        [{enable_soap,true},   % <== THIS WILL ENABLE SOAP IN A YAWS SERVER!!
                         {trace, false},
                         {tmpdir,Tmpdir},{logdir,Logdir},
                         {flags,[{tty_trace, false}, {copy_errlog, true}]}]),
    yaws_soap_lib:write_hrl("www/billingserver.wsdl", "billingserver.hrl"),
    yaws_soap_srv:setup({soapbilling, handler}, "www/billingserver.wsdl");
 

bs_start(init) ->
    deinit(),
    mnesia_init_env(),
    initschema(),
    bs_start(all).

bs_start() ->
    mnesia_init_env(),
    mnesia:start(),
    bs_start(all).

bs_stop() ->
    yaws:stop(),
    mnesia:stop().

bs_account_list() ->
    SelectFun = fun() ->
                        MatchHead = #account{accountnumber='$1', balance='$2'},
                        Guards = [],
                        Results = [['$1', '$2']],
                        mnesia:dirty_select(account,[{MatchHead, Guards, Results}])
                end,
    case mnesia:transaction(SelectFun) of
        {atomic, Result} -> Result;
        {aborted, Reason} -> Reason
    end.

bs_transaction_list() ->
    SelectFun = fun() ->
                        MatchHead = #transaction{transactionid='$1',
                                                 accountnumber='$2', amount='$3',
                                                 finished='$4'},
                        Guards = [],
                        Results = [['$1', '$2', '$3', '$4']],
                        mnesia:dirty_select(transaction,[{MatchHead, Guards, Results}])
                end,
    case mnesia:transaction(SelectFun) of
        {atomic, Result} -> Result;
        {aborted, Reason} -> Reason
    end.

transaction_list(AccountNumber, Finished) ->
    SelectFun = fun() ->
                        MatchHead = #transaction{transactionid='$1',
                                                 accountnumber='$2', amount='$3',
                                                 finished='$4'},
                        Guards = [{'==','$2',AccountNumber}, {'==', '$4', Finished}],
                        Results = [['$1', '$2', '$3', '$4']],
                        mnesia:dirty_select(transaction,[{MatchHead, Guards, Results}])
                end,
    case mnesia:transaction(SelectFun) of
        {atomic, Result} -> Result;
        {aborted, Reason} -> Reason
    end.

bs_unfinished_transaction_list(AccountNumber) ->
    transaction_list(AccountNumber, false).

bs_finished_transaction_list(AccountNumber) ->
    transaction_list(AccountNumber, true).
