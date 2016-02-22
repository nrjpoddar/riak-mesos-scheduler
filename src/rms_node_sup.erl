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

-module(rms_node_sup).

-behaviour(supervisor).

-export([start_link/0]).

-export([start_node/1]).

-export([init/1]).

%% External functions.

-spec start_link() -> {ok, pid()}.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, {}).

-spec start_node(rms_node:key()) -> {ok, pid()}.
start_node(Key) ->
    NodeSpec = {Key,
                   {rms_node, start_link, [Key]},
                   transient, 5000, worker, [rms_node]},
    supervisor:start_child(?MODULE, NodeSpec).

%% supervisor callback function.

init({}) ->
    {ok, {{one_for_one, 10, 10}, []}}.
