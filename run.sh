#!/bin/bash

echo "${CONTAINER_NAME} version ${JMETER_CONTAINER_VERSION}"
echo
echo Image built date: $(cat ${JMETER_HOME}/build-date.txt)
echo
mkdir -p $JMETER_RESULTS
echo
echo "Current HEAP settings ..."
echo "HEAP=$HEAP"
echo

for FILE in $JMETER_TESTPLANS/*; 
    do
        echo
        echo "Executing test plan: $FILE ..."
        echo 
        echo "Running command ... "
        echo
        echo "jmeter -n -t $FILE -l $JMETER_RESULTS/kafka-jmeter-result.jtl \ "
        echo "-Jjmeter.threads=$JMETER_THREADS \ "
        echo "-Jbootstrap.servers=$BOOTSTRAP_SERVERS \ "
        echo "-Jbatch.size=$BATCH_SIZE \ "
        echo "-Jlinger.ms=$LINGER_MS \ "
        echo "-Jbuffer.memory=$BUFFER_MEMORY \ "
        echo "-Jacks=$ACKS \ "
        echo "-Jcompression.type=$COMPRESSION_TYPE \ "
        echo "-Jsend_buffer.bytes=$SEND_BUFFER \ "
        echo "-Jreceive_buffer.bytes=$RECEIVE_BUFFER \ "
        echo "-Jkafka.topic=$KAFKA_TOPIC \ "
        echo "-Jpartition.no=$PARTITION_NO \ "
        echo "-Jramup.period=$RAMUP_PERIOD \ "
        echo "-Jloop.count=$LOOP_COUNT \ "
        echo "-Jprometheus.port=$PROMETHEUS_PORT \ "
        echo "-Jprometheus.ip=$PROMETHEUS_HOST \ "
        echo "\"-Jsampler.label=$SAMPLER_LABEL\" \ "
        echo "\"-Jkafka.message=$KAFKA_MESSAGE\" \ "
        echo "-Jthreadgroup.scheduler=$THREADGROUP_SCHEDULER \ "
        echo "-Jthreadgroup.duration=$THREADGROUP_DURATION \ "
        echo "-Jthreadgroup.delay=$THREADGROUP_DELAY \ "
        echo "-Jthreadgroup.same_user_on_next_iteration=$THREADGROUP_SAME_USER_NEXT_ITERATION \ "
        echo "-Jthreadgroup.delaystart=$THREADGROUP_DELAYSTART;"
        echo
        
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
        "-Jsampler.label=$SAMPLER_LABEL" \
        "-Jkafka.message=$KAFKA_MESSAGE" \
        -Jthreadgroup.scheduler=$THREADGROUP_SCHEDULER \
        -Jthreadgroup.duration=$THREADGROUP_DURATION \
        -Jthreadgroup.delay=$THREADGROUP_DELAY \
        -Jthreadgroup.same_user_on_next_iteration=$THREADGROUP_SAME_USER_NEXT_ITERATION \
        -Jthreadgroup.delaystart=$THREADGROUP_DELAYSTART;
done

