%% -------------------------------------------------------------------
%%
%% Copyright (c) 2015 Basho Technologies Inc. All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

-module(riak_mesos_scheduler).

-behaviour(erl_mesos_scheduler).

-include_lib("erl_mesos/include/erl_mesos.hrl").

-export([init/1,
         registered/3,
         reregistered/2,
         disconnected/2,
         status_update/3,
         resource_offers/3,
         offer_rescinded/3,
         error/3,
         handle_info/3,
         terminate/3]).

-record(state, {callback}).

%%%===================================================================
%%% Callbacks
%%%===================================================================

init(Options) ->
    FrameworkInfo = framework_info(),
    lager:info("~n~p~n~p", [Options, FrameworkInfo]),
    {ok, FrameworkInfo, true, #state{callback = init}}.

registered(_SchedulerInfo, EventSubscribed, State) ->
    lager:info("~p", [EventSubscribed]),
    {ok, State#state{callback = registered}}.

disconnected(_SchedulerInfo, State) ->
    lager:info("disconnected", []),
    {ok, State#state{callback = disconnected}}.

reregistered(_SchedulerInfo, State) ->
    lager:info("reregistered", []),
    {ok, State#state{callback = reregistered}}.

status_update(_SchedulerInfo, StatusUpdates,State) ->
    lager:info("~p", [StatusUpdates]),
    {ok, State#state{callback = status_update}}.

resource_offers(SchedulerInfo, #event_offers{offers = Offers}, State) ->
    lager:info("~p", [Offers]),
    [#offer{id = OfferId,
            agent_id = #agent_id{value = AgentIdValue}} | _] = Offers,

    AgentIdObj = erl_mesos_obj:new([{<<"value">>, AgentIdValue}]),
    TaskIdObj = erl_mesos_obj:new([{<<"value">>, <<"2">>}]),
%%    CommandInfoUriObj = erl_mesos_obj:new([{<<"value">>, <<"test-executor">>}]),
%%    CommandInfoObj = erl_mesos_obj:new([{<<"uris">>, [CommandInfoUriObj]},
%%                                        {<<"shell">>, false}]),
    CommandValue = <<"while true; do echo 'Test task is running...'; sleep 1; done">>,
    CommandInfoObj = erl_mesos_obj:new([{<<"shell">>, true},
                                        {<<"value">>, CommandValue}]),
    CpuScalarObj = erl_mesos_obj:new([{<<"value">>, 0.1}]),
    ResourceCpuObj = erl_mesos_obj:new([{<<"name">>, <<"cpus">>},
                                        {<<"type">>, <<"SCALAR">>},
                                        {<<"scalar">>, CpuScalarObj}]),
    TaskInfoObj = erl_mesos_obj:new([{<<"name">>, <<"TEST TASK">>},
                                     {<<"task_id">>, TaskIdObj},
                                     {<<"agent_id">>, AgentIdObj},
                                     {<<"command">>, CommandInfoObj},
                                     {<<"resources">>, [ResourceCpuObj]}]),
    Launch = #offer_operation_launch{task_infos = [TaskInfoObj]},
    OfferOperation = #offer_operation{type = <<"LAUNCH">>,
                                      launch = Launch},
    CallAccept = #call_accept{offer_ids = [OfferId],
                              operations = [OfferOperation]},
    Result = erl_mesos_scheduler:accept(SchedulerInfo, CallAccept),
    lager:info("Result ~p", [Result]),
    {ok, State#state{callback = resource_offers}}.

offer_rescinded(_SchedulerInfo, EventRescind, State) ->
    lager:info("~p", [EventRescind]),
    {ok, State#state{callback = offer_rescinded}}.

error(_SchedulerInfo, EventError, State) ->
    lager:error("~p", [EventError]),
    {stop, State#state{callback = error}}.

handle_info(_SchedulerInfo, stop, State) ->
    lager:info("stopped", []),
    {stop, State};
handle_info(_SchedulerInfo, Info, State) ->
    lager:warn("~p", [Info]),
    {ok, State}.

terminate(_SchedulerInfo, Reason, _State) ->
    lager:warning("~p", [Reason]),
    ok.

%% ====================================================================
%% Private
%% ====================================================================

framework_info() ->
    User = riak_mesos_config:get_value(user, <<"root">>, binary),
    Name = riak_mesos_config:get_value(name, <<"riak">>, binary),
    Role = riak_mesos_config:get_value(role, <<"riak">>, binary),
    Hostname = riak_mesos_config:get_value(hostname, undefined, binary),
    Principal = riak_mesos_config:get_value(principal, <<"riak">>, binary),

    #framework_info{user = User,
                    name = Name,
                    role = Role,
                    hostname = Hostname,
                    principal = Principal,
                    checkpoint = undefined, %% TODO: We will want to enable checkpointing
                    id = undefined, %% TODO: Will need to check ZK for this for reregistration
                    webui_url = undefined, %% TODO: Get this from webmachine helper probably
                    failover_timeout = undefined, %% TODO: Add this to configurable options
                    capabilities = undefined,
                    labels = undefined}.
