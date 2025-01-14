#! /usr/bin/env escript
%%! -smp enable -mnesia debug verbose -Wall -pz ../../ebin/ ../../deps/gen_logger/ebin ../../deps/goldrush/ebin ../../deps/lager/ebin ../../deps/ibrowse/ebin ../../deps/jiffy/ebin ../../deps/snowflake/ebin

-module(yunba_simple_test).

-include("../../include/emqttc_packet.hrl").
-include("../../include/emqttc_yunba_misc.hrl").

-export([start/0]).

start() ->
    ok = application:start(ibrowse),  %% start ibrowse to support http get/post
    ok = application:start(snowflake),

    %% register your appkey, get clientid, username and password
    {ok, {ClientId, UserName, Password}} =
        emqttc_register:register(?YUNBA_REG_URL, ?TEST_APPKEY, ?TEST_PLATFORM),

    %% get MQTT broker IP (host and port) from yunba tick service
    {ok, {Host, Port}} = emqttc_broker:get_broker(?YUNBA_TICK_URL),

    %% connect MQTT broker
    {ok, Client} = emqttc:start_link([{host, Host}, {port, Port}, {client_id, ClientId},
                                      {proto_ver, ?MQTT_PROTO_V31_YUNBA},
                                      {username, UserName},
                                      {password, Password}]),

    %% subscribe the test topic
    emqttc:subscribe(Client, ?TEST_TOPIC, ?QOS_0),
    receive
        {suback, PacketId} ->
            io:format("Received suback of ~p~n", [PacketId])
    after
        ?TEST_TIMEOUT ->
            io:format("Waiting for suback timeout")
    end,

    timer:sleep(2000),

    %% publish the message
    emqttc:publish(Client, ?TEST_TOPIC, ?TEST_PAYLOAD, qos0),

    %% waiting for receiving the message that we published
    receive
        {publish, Topic, Payload} ->
            io:format("Message Received from ~s: ~p~n", [Topic, Payload])
    after
        ?TEST_TIMEOUT ->
            io:format("Error: receive timeout!~n")
    end,

    %% unsubscribe the topic
    emqttc:unsubscribe(Client, ?TEST_TOPIC),

    %% disconnect the broker after finishing the simple test
    emqttc:disconnect(Client).

main(_Args) ->
    start().
