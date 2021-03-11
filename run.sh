#!/bin/bash

echo
echo "Creating the following path in container volume ..."
echo "     JMeter Result Path: $JMETER_RESULTS"
echo
mkdir -p $JMETER_RESULTS

echo "Current HEAP settings ..."
echo "HEAP=$HEAP"

for FILE in $JMETER_TESTPLANS/*; 
    do
        echo
        echo "Executing test plan: $FILE ..."
        echo 
        echo "command: jmeter -n -t $FILE -l $JMETER_RESULTS/kafka-jmeter-result.jtl -Jjmeter.threads=$JMETER_THREADS -Jbootstrap.servers=$BOOTSTRAP_SERVERS -Jbatch.size=$BATCH_SIZE -Jlinger.ms=$LINGER_MS -Jbuffer.memory=$BUFFER_MEMORY -Jacks=$ACKS -Jcompression.type=$COMPRESSION_TYPE -Jsend_buffer.bytes=$SEND_BUFFER -Jreceive_buffer.bytes=$RECEIVE_BUFFER -Jkafka.topic=$KAFKA_TOPIC -Jpartition.no=$PARTITION_NO -Jramup.period=$RAMUP_PERIOD -Jloop.count=$LOOP_COUNT -Jprometheus.port=$PROMETHEUS_PORT -Jprometheus.ip=$PROMETHEUS_HOST -Jsampler.label=$SAMPLER_LABEL -Jkafka.message=$KAFKA_MESSAGE;"
        
        jmeter -n -t $FILE -l $JMETER_RESULTS/kafka-jmeter-result.jtl \
        -Jjmeter.threads=$JMETER_THREADS \
        -Jbootstrap.servers=$BOOTSTRAP_SERVERS \
        -Jbatch.size=$BATCH_SIZE \
        -Jlinger.ms=$LINGER_MS \
        -Jbuffer.memory=$BUFFER_MEMORY \
        -Jacks=$ACKS \
        -Jcompression.type=$COMPRESSION_TYPE \
        -Jsend_buffer.bytes=$SEND_BUFFER \
        -Jreceive_buffer.bytes=$RECEIVE_BUFFER \
        -Jkafka.topic=$KAFKA_TOPIC \
        -Jpartition.no=$PARTITION_NO \
        -Jramup.period=$RAMUP_PERIOD \
        -Jloop.count=$LOOP_COUNT \
        -Jprometheus.port=$PROMETHEUS_PORT \
        -Jprometheus.ip=$PROMETHEUS_HOST \
        -Jsampler.label=$SAMPLER_LABEL \
        -Jkafka.message=$KAFKA_MESSAGE \
        -Jthreadgroup.scheduler=$THREADGROUP_SCHEDULER \
        -Jthreadgroup.duration=$THREADGROUP_DURATION \
        -Jthreadgroup.delay=$THREADGROUP_DELAY \
        -Jthreadgroup.same_user_on_next_iteration=$THREADGROUP_SAME_USER_NEXT_ITERATION \
        -Jthreadgroup.delaystart=$THREADGROUP_DELAYSTART;
done

