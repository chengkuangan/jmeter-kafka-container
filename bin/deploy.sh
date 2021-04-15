#!/bin/bash

########################################################################################################################
### 
### Configuration script for JMeter environment in OpenShift.
### Contributed By: CK Gan (chgan@redhat.com)
### Complete setup guide and documentation at https://github.com/chengkuangan/jmeter-container
### 
########################################################################################################################

APPS_NAMESPACE="kafka-jmeter"
APPS_PROJECT_DISPLAYNAME="Kafka Load Testing"
OC_USER=""
PROCEED_INSTALL="no"

KAFKA_CLUSTER_NAME="kafka-cluster"
KAFKA_TEMPLATE_FILENAME="kafka-persistent.yaml"
PARTITION_REPLICA_NUM=3
TOPIC_PARTITION_NUM="3"
KAFKA_TOPIC="jmeter-kafka"
KAFKA_VERSION="2.6.0"
KAFKA_LOGFORMAT_VERSION="2.6"
KAFKA_INTER_BROKER_PROTOCOL_VERSION="2.6"
TRANSACTION_STATE_LOG_MIN_ISR="2"
BACKGROUND_THREADS="10"      
MIN_INSYNC_REPLICAS="1"      
REPLICA_FETCH_MAX_BYTES="1048576"
REPLICA_SOCKET_RECEIVE_BUFFER_BYTES="65536"
NUM_REPLICA_FETCHERS="1"
NUM_IO_THREADS="8"
NUM_NETWORK_THREADS="3"
NUM_REPLICA_FETCHER="3"
REPLICA_FETCH_MIN_BYTES="1"
REPLICA_FETCH_RESPONSE_MAX_BYTES="10485760"
KAKFA_STORAGE_SIZE="100Gi"
ZOOKEEPER_STORAGE_SIZE="10Gi"


RED='\033[1;31m'
NC='\033[0m' # No Color
GREEN='\033[1;32m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
YELLOW='\033[1;33m'

function init(){
    
    set echo off
    OC_USER="$(oc whoami)"
    set echo on
    
    if [ $? -ne 0 ] || [ "$OC_USER" = "" ]; then
        echo
        printWarning "Please login to Openshift before proceed ..."
        echo
        exit 0
    fi
    echo
    printHeader "--> Creating temporary directory ../tmp"
    mkdir ../tmp

    printHeader "--> Create OpenShift required projects if not already created"

    oc new-project $APPS_NAMESPACE
    
}

#function validates(){
    #if [ $PARTITION_REPLICA_NUM < 2 ]; then
    #    printWarning "PARTITION_REPLICA_NUM must be at least 2."
    #    exit 0
    #fi
#}

function printTitle(){
    HEADER=$1
    echo -e "${RED}$HEADER${NC}"
}

function printHeader(){
    HEADER=$1
    echo -e "${YELLOW}$HEADER${NC}"
}

function printLink(){
    LINK=$1
    echo -e "${GREEN}$LINK${NC}"
}

function printCommand(){
    COMMAND=$1
    echo -e "${GREEN}$COMMAND${NC}"
}

function printWarning(){
    WARNING=$1
    echo -e "${RED}$WARNING${NC}"
}

function printError(){
    ERROR=$1
    echo -e "${RED}$ERROR${NC}"
}

function printVariables(){
    echo 
    printHeader "The following is the parameters enter..."
    echo
    echo "APPS_NAMESPACE = $APPS_NAMESPACE"
    echo "APPS_PROJECT_DISPLAYNAME = $APPS_PROJECT_DISPLAYNAME"
    echo "OC_USER = $OC_USER"
    echo "KAFKA_CLUSTER_NAME = $KAFKA_CLUSTER_NAME"
    echo "KAFKA_TEMPLATE_FILENAME = $KAFKA_TEMPLATE_FILENAME"
    echo "PARTITION_REPLICA_NUM = $PARTITION_REPLICA_NUM"
    echo "TOPIC_PARTITION_NUM = $TOPIC_PARTITION_NUM"
    echo "KAFKA_TOPIC = $KAFKA_TOPIC"
    echo "KAFKA_VERSION = $KAFKA_VERSION" 
    echo "KAFKA_LOGFORMAT_VERSION = $KAFKA_LOGFORMAT_VERSION"
    echo "KAFKA_INTER_BROKER_PROTOCOL_VERSION = $KAFKA_INTER_BROKER_PROTOCOL_VERSION"
    echo "TRANSACTION_STATE_LOG_MIN_ISR = $TRANSACTION_STATE_LOG_MIN_ISR"
    echo "BACKGROUND_THREADS = $BACKGROUND_THREADS"      
    echo "MIN_INSYNC_REPLICAS = $MIN_INSYNC_REPLICAS"      
    echo "REPLICA_FETCH_MAX_BYTES = $REPLICA_FETCH_MAX_BYTES"
    echo "REPLICA_SOCKET_RECEIVE_BUFFER_BYTES = $REPLICA_SOCKET_RECEIVE_BUFFER_BYTES"
    echo "NUM_REPLICA_FETCHERS = $NUM_REPLICA_FETCHERS"
    echo "NUM_IO_THREADS = $NUM_IO_THREADS"
    echo "NUM_NETWORK_THREADS = $NUM_NETWORK_THREADS"
    echo "NUM_REPLICA_FETCHER = $NUM_REPLICA_FETCHER"
    echo "REPLICA_FETCH_MIN_BYTES = $REPLICA_FETCH_MIN_BYTES"
    echo "REPLICA_FETCH_RESPONSE_MAX_BYTES = $REPLICA_FETCH_RESPONSE_MAX_BYTES"
    echo "KAKFA_STORAGE_SIZE = $KAKFA_STORAGE_SIZE"
    echo "ZOOKEEPER_STORAGE_SIZE = $ZOOKEEPER_STORAGE_SIZE"
    echo

}

## ==================================================
## ---- Common steps to confighure Prometheus 
## ==================================================
function configurePrometheus(){

    echo
    printHeader "--> Configure Prometheus for $APPS_NAMESPACE namespace ... "
    echo
    
    echo
    echo "Creating the cluster-monitoring-config configmap ... "
    echo
    oc apply -f ../templates/cluster-monitoring-config.yaml  -n openshift-monitoring
    
    catchError "Error creating clustermonitoring-config configmap."

    echo
    echo "Configuring Grafana for $APPS_NAMESPACE namespace ... "
    echo
    
    cp ../templates/grafana-sa.yaml ../tmp/grafana-sa.yaml
    catchError "Error copying ../templates/grafana-sa.yaml."

    sed -i -e "s/myproject/$APPS_NAMESPACE/" ../tmp/grafana-sa.yaml
    catchError "Error sed ../tmp/grafana-sa.yaml."

    oc apply -f ../tmp/grafana-sa.yaml -n $APPS_NAMESPACE
    catchError "Error oc applying ../tmp/grafana-sa.yaml."

    GRAFANA_SA_TOKEN="$(oc serviceaccounts get-token grafana-serviceaccount -n $APPS_NAMESPACE)"
    catchError "Error get-token for grafana-serviceaccount"

    cp ../templates/datasource.yaml ../tmp/datasource.yaml
    catchError "Error copying ../templates/datasource.yaml."

    sed -i -e "s/GRAFANA-ACCESS-TOKEN/$GRAFANA_SA_TOKEN/" ../tmp/datasource.yaml
    catchError "Error sed for ../tmp/datasource.yaml"

    oc create configmap grafana-config --from-file=../tmp/datasource.yaml -n $APPS_NAMESPACE
    catchError "Error create configmap grafana-config"

    oc apply -f ../templates/grafana.yaml -n $APPS_NAMESPACE
    catchError "Error applying ../templates/grafana.yaml"

    oc create route edge grafana --service=grafana -n $APPS_NAMESPACE
    catchError "Error create route edge grafana"
}

function catchError(){
    if [ $? -ne 0 ]; then
        echo
        printError "Error running the command ... Please see the previous command line."
        echo
        printError $1
        removeTempDirs
        exit 0
    fi
}

function configurePrometheus4JMeter(){

    echo
    printHeader "--> Configure Prometheus for JMeter ... "
    echo
    
    cp ../templates/jmeter/prometheus/jmeter-service-monitor.yml ../tmp/jmeter-service-monitor.yml
    catchError "Error copying ../templates/jmeter/prometheus/jmeter-service-monitor.yml"

    sed -i -e "s/myproject/$APPS_NAMESPACE/" ../tmp/jmeter-service-monitor.yml
    catchError "Error sed ../tmp/jmeter-service-monitor.yml"

    oc apply -f ../tmp/jmeter-service-monitor.yml  -n $APPS_NAMESPACE
    catchError "Error applying ../tmp/jmeter-service-monitor.yml"
}

function configurePrometheus4Kafka(){

    echo
    printHeader "--> Configuring Prometheus for Kafka in namespace $APPS_NAMESPACE ... "
    echo
    
    cp ../templates/kafka/prometheus/strimzi-pod-monitor.yaml ../tmp/strimzi-pod-monitor.yaml
    catchError "Error copying ../templates/kafka/prometheus/strimzi-pod-monitor.yaml"
    sed -i -e "s/myproject/$APPS_NAMESPACE/" ../tmp/strimzi-pod-monitor.yaml
    catchError "Error sed ../tmp/strimzi-pod-monitor.yaml"
    oc apply -f ../tmp/strimzi-pod-monitor.yaml  -n $APPS_NAMESPACE
    catchError "Error applying ../tmp/strimzi-pod-monitor.yaml"
    oc apply -f ../templates/kafka/prometheus/prometheus-rules.yaml  -n $APPS_NAMESPACE
    catchError "Error applyting ../templates/kafka/prometheus/prometheus-rules.yaml"
}

function deployKafka(){
    echo
    printHeader "--> Modifying ../templates/kafka/$KAFKA_TEMPLATE_FILENAME"
    echo
    
    cp ../templates/kafka/$KAFKA_TEMPLATE_FILENAME ../tmp/$KAFKA_TEMPLATE_FILENAME
    catchError "Error copying ../templates/kafka/$KAFKA_TEMPLATE_FILENAME"

    sed -i -e "s/version:.*/version: $KAFKA_VERSION/" ../tmp/$KAFKA_TEMPLATE_FILENAME
    catchError "Error sed ../tmp/$KAFKA_TEMPLATE_FILENAME"

    sed -i -e "s/log.message.format.version:.*/log.message.format.version: '$KAFKA_LOGFORMAT_VERSION'/" ../tmp/$KAFKA_TEMPLATE_FILENAME
    catchError "Error sed ../tmp/$KAFKA_TEMPLATE_FILENAME"

    sed -i -e "s/inter.broker.protocol.version:.*/inter.broker.protocol.version: '$KAFKA_INTER_BROKER_PROTOCOL_VERSION'/" ../tmp/$KAFKA_TEMPLATE_FILENAME
    catchError "Error sed ../tmp/$KAFKA_TEMPLATE_FILENAME"
    

    sed -i -e "s/kafka-sizing/$APPS_NAMESPACE/" ../tmp/$KAFKA_TEMPLATE_FILENAME
    catchError "Error sed ../tmp/$KAFKA_TEMPLATE_FILENAME"

    sed -i -e "s/my-cluster/$KAFKA_CLUSTER_NAME/" ../tmp/$KAFKA_TEMPLATE_FILENAME
    catchError "Error sed ../tmp/$KAFKA_TEMPLATE_FILENAME"

    sed -i -e "s/transaction.state.log.min.isr:.*/transaction.state.log.min.isr: $TRANSACTION_STATE_LOG_MIN_ISR/" ../tmp/$KAFKA_TEMPLATE_FILENAME
    catchError "Error sed ../tmp/$KAFKA_TEMPLATE_FILENAME"

    sed -i -e "s/min.insync.replicas:.*/min.insync.replicas: $MIN_INSYNC_REPLICAS/" ../tmp/$KAFKA_TEMPLATE_FILENAME
    catchError "Error sed ../tmp/$KAFKA_TEMPLATE_FILENAME"

    sed -i -e "s/background.threads:.*/background.threads: $BACKGROUND_THREADS/" ../tmp/$KAFKA_TEMPLATE_FILENAME
    catchError "Error sed ../tmp/$KAFKA_TEMPLATE_FILENAME"

    sed -i -e "s/replica.fetch.max.bytes:.*/replica.fetch.max.bytes: $REPLICA_FETCH_MAX_BYTES/" ../tmp/$KAFKA_TEMPLATE_FILENAME
    catchError "Error sed ../tmp/$KAFKA_TEMPLATE_FILENAME"

    sed -i -e "s/replica.socket.receive.buffer.bytes:.*/replica.socket.receive.buffer.bytes: $REPLICA_SOCKET_RECEIVE_BUFFER_BYTES/" ../tmp/$KAFKA_TEMPLATE_FILENAME
    catchError "Error sed ../tmp/$KAFKA_TEMPLATE_FILENAME"

    sed -i -e "s/num.replica.fetchers:.*/num.replica.fetchers: $NUM_REPLICA_FETCHERS/" ../tmp/$KAFKA_TEMPLATE_FILENAME
    catchError "Error sed ../tmp/$KAFKA_TEMPLATE_FILENAME"

    sed -i -e "s/num.io.threads:.*/num.io.threads: $NUM_IO_THREADS/" ../tmp/$KAFKA_TEMPLATE_FILENAME
    catchError "Error sed ../tmp/$KAFKA_TEMPLATE_FILENAME"

    sed -i -e "s/num.network.threads:.*/num.network.threads: $NUM_NETWORK_THREADS/" ../tmp/$KAFKA_TEMPLATE_FILENAME
    catchError "Error sed ../tmp/$KAFKA_TEMPLATE_FILENAME"

    sed -i -e "s/num.replica.fetchers:.*/num.replica.fetchers: $NUM_REPLICA_FETCHER/" ../tmp/$KAFKA_TEMPLATE_FILENAME
    catchError "Error sed ../tmp/$KAFKA_TEMPLATE_FILENAME"

    sed -i -e "s/replica.fetch.min.bytes:.*/replica.fetch.min.bytes: $REPLICA_FETCH_MIN_BYTES/" ../tmp/$KAFKA_TEMPLATE_FILENAME
    catchError "Error sed ../tmp/$KAFKA_TEMPLATE_FILENAME"

    sed -i -e "s/replica.fetch.response.max.bytes:.*/replica.fetch.response.max.bytes: $REPLICA_FETCH_RESPONSE_MAX_BYTES/" ../tmp/$KAFKA_TEMPLATE_FILENAME
    catchError "Error sed ../tmp/$KAFKA_TEMPLATE_FILENAME"

    sed -i -e "s/size: 100Gi/size: $KAKFA_STORAGE_SIZE/" ../tmp/$KAFKA_TEMPLATE_FILENAME
    catchError "Error sed ../tmp/$KAFKA_TEMPLATE_FILENAME"

    sed -i -e "s/size: 10Gi/size: $ZOOKEEPER_STORAGE_SIZE/" ../tmp/$KAFKA_TEMPLATE_FILENAME
    catchError "Error sed ../tmp/$KAFKA_TEMPLATE_FILENAME"

    echo 
    printHeader "--> Deploying AMQ Streams (Kafka) Cluster now ... Using ../templates/kafka/$KAFKA_TEMPLATE_FILENAME ..."
    oc create -f ../tmp/$KAFKA_TEMPLATE_FILENAME -n $APPS_NAMESPACE
    catchError "Error applying ../tmp/$KAFKA_TEMPLATE_FILENAME"
    
}

function createKafkaTopic(){
    echo
    printHeader "--> Creating Kafka Topic ..."
    echo
    cp ../templates/kafka/kafka-topic.yaml ../tmp/kafka-topic.yaml
    catchError "Error copying ../templates/kafka/kafka-topic.yaml"
    sed -i -e "s/mytopic/$KAFKA_TOPIC/" ../tmp/kafka-topic.yaml
    catchError "Error sed ../tmp/kafka-topic.yaml"
    sed -i -e "s/mycluster/$KAFKA_CLUSTER_NAME/" ../tmp/kafka-topic.yaml
    catchError "Error sed ../tmp/kafka-topic.yaml"
    sed -i -e "s/partitions:.*/partitions: $TOPIC_PARTITION_NUM/" ../tmp/kafka-topic.yaml
    catchError "Error sed ../tmp/kafka-topic.yaml"
    sed -i -e "s/replicas:.*/replicas: $PARTITION_REPLICA_NUM/" ../tmp/kafka-topic.yaml
    catchError "Error sed ../tmp/kafka-topic.yaml"
    oc apply -f ../tmp/kafka-topic.yaml -n $APPS_NAMESPACE
    catchError "Error applying ../tmp/kafka-topic.yaml"
    echo
}

function deployKafkaRelated(){
    deployKafka
    createKafkaTopic
    configurePrometheus4Kafka
}

function deployJMeterRelated(){
    configurePrometheus4JMeter
}

# ----- Remove all tmp content after completed.
function removeTempDirs(){
    echo
    printHeader "--> Removing ../tmp directory ... "
    echo
    rm -rf ../tmp
}

# ----- read user inputs for installation parameters
function readInput(){
    INPUT_VALUE=""
    echo
    printHeader "Please provides the following parameter values. (Enter q to quit)"
    echo
    while [ "$INPUT_VALUE" != "q" ]
    do  
    
        printf "Namespace [$APPS_NAMESPACE]:"
        read INPUT_VALUE
        if [ "$INPUT_VALUE" != "" ] && [ "$INPUT_VALUE" != "q" ]; then
            APPS_NAMESPACE="$INPUT_VALUE"
        fi
        
        checkQuitInput $INPUT_VALUE

        printf "Kafka Cluster Name [$KAFKA_CLUSTER_NAME]:"
        read INPUT_VALUE
        if [ "$INPUT_VALUE" != "" ] && [ "$INPUT_VALUE" != "q" ]; then
            KAFKA_CLUSTER_NAME="$INPUT_VALUE"
        fi

        checkQuitInput $INPUT_VALUE

        printf "Kafka Version [$KAFKA_VERSION]:"
        read INPUT_VALUE
        if [ "$INPUT_VALUE" != "" ] && [ "$INPUT_VALUE" != "q" ]; then
            KAFKA_VERSION="$INPUT_VALUE"
        fi

        checkQuitInput $INPUT_VALUE

        printf "Kafka Log Format Version [$KAFKA_LOGFORMAT_VERSION]:"
        read INPUT_VALUE
        if [ "$INPUT_VALUE" != "" ] && [ "$INPUT_VALUE" != "q" ]; then
            KAFKA_LOGFORMAT_VERSION="$INPUT_VALUE"
        fi

        checkQuitInput $INPUT_VALUE

        printf "Kafka Inter Broker Protocol Version [$KAFKA_INTER_BROKER_PROTOCOL_VERSION]:"
        read INPUT_VALUE
        if [ "$INPUT_VALUE" != "" ] && [ "$INPUT_VALUE" != "q" ]; then
            KAFKA_INTER_BROKER_PROTOCOL_VERSION="$INPUT_VALUE"
        fi

        checkQuitInput $INPUT_VALUE
        

        printf "No of Partition [$TOPIC_PARTITION_NUM]:"
        read INPUT_VALUE
        if [ "$INPUT_VALUE" != "" ] && [ "$INPUT_VALUE" != "q" ]; then
            TOPIC_PARTITION_NUM="$INPUT_VALUE"
        fi

        checkQuitInput $INPUT_VALUE

        printf "No of Replica per Partition [$PARTITION_REPLICA_NUM]:"
        read INPUT_VALUE
        if [ "$INPUT_VALUE" != "" ] && [ "$INPUT_VALUE" != "q" ]; then
            PARTITION_REPLICA_NUM="$INPUT_VALUE"
        fi

        checkQuitInput $INPUT_VALUE

        printf "Min ISR [$MIN_INSYNC_REPLICAS]:"
        read INPUT_VALUE
        if [ "$INPUT_VALUE" != "" ] && [ "$INPUT_VALUE" != "q" ]; then
            MIN_INSYNC_REPLICAS="$INPUT_VALUE"
        fi

        checkQuitInput $INPUT_VALUE

        printf "No Replica Fetcher [$NUM_REPLICA_FETCHERS]:"
        read INPUT_VALUE
        if [ "$INPUT_VALUE" != "" ] && [ "$INPUT_VALUE" != "q" ]; then
            NUM_REPLICA_FETCHERS="$INPUT_VALUE"
        fi

        checkQuitInput $INPUT_VALUE

        printf "Replica Fetch Min Bytes [$REPLICA_FETCH_MIN_BYTES]:"
        read INPUT_VALUE
        if [ "$INPUT_VALUE" != "" ] && [ "$INPUT_VALUE" != "q" ]; then
            REPLICA_FETCH_MIN_BYTES="$INPUT_VALUE"
        fi

        checkQuitInput $INPUT_VALUE

        printf "Replica Fetch Max Bytes [$REPLICA_FETCH_MAX_BYTES]:"
        read INPUT_VALUE
        if [ "$INPUT_VALUE" != "" ] && [ "$INPUT_VALUE" != "q" ]; then
            REPLICA_FETCH_MAX_BYTES="$INPUT_VALUE"
        fi

        checkQuitInput $INPUT_VALUE

        printf "Replica Fetch Response Max Bytes [$REPLICA_FETCH_RESPONSE_MAX_BYTES]:"
        read INPUT_VALUE
        if [ "$INPUT_VALUE" != "" ] && [ "$INPUT_VALUE" != "q" ]; then
            REPLICA_FETCH_RESPONSE_MAX_BYTES="$INPUT_VALUE"
        fi

        checkQuitInput $INPUT_VALUE

        printf "Replica Socket Receive Buffer Bytes [$REPLICA_SOCKET_RECEIVE_BUFFER_BYTES]:"
        read INPUT_VALUE
        if [ "$INPUT_VALUE" != "" ] && [ "$INPUT_VALUE" != "q" ]; then
            REPLICA_SOCKET_RECEIVE_BUFFER_BYTES="$INPUT_VALUE"
        fi

        checkQuitInput $INPUT_VALUE

        printf "Transaction State Log Min ISR [$TRANSACTION_STATE_LOG_MIN_ISR]:"
        read INPUT_VALUE
        if [ "$INPUT_VALUE" != "" ] && [ "$INPUT_VALUE" != "q" ]; then
            TRANSACTION_STATE_LOG_MIN_ISR="$INPUT_VALUE"
        fi

        checkQuitInput $INPUT_VALUE

        printf "Background Threads [$BACKGROUND_THREADS]:"
        read INPUT_VALUE
        if [ "$INPUT_VALUE" != "" ] && [ "$INPUT_VALUE" != "q" ]; then
            BACKGROUND_THREADS="$INPUT_VALUE"
        fi

        checkQuitInput $INPUT_VALUE

        printf "Num IO Threads [$NUM_IO_THREADS]:"
        read INPUT_VALUE
        if [ "$INPUT_VALUE" != "" ] && [ "$INPUT_VALUE" != "q" ]; then
            NUM_IO_THREADS="$INPUT_VALUE"
        fi

        checkQuitInput $INPUT_VALUE

        printf "Num Network Threads [$NUM_NETWORK_THREADS]:"
        read INPUT_VALUE
        if [ "$INPUT_VALUE" != "" ] && [ "$INPUT_VALUE" != "q" ]; then
            NUM_NETWORK_THREADS="$INPUT_VALUE"
        fi

        checkQuitInput $INPUT_VALUE

        printf "Kafka Topic [$KAFKA_TOPIC]:"
        read INPUT_VALUE
        if [ "$INPUT_VALUE" != "" ] && [ "$INPUT_VALUE" != "q" ]; then
            KAFKA_TOPIC="$INPUT_VALUE"
        fi

        checkQuitInput $INPUT_VALUE

        printf "Kafka Storage Size [$KAKFA_STORAGE_SIZE]:"
        read INPUT_VALUE
        if [ "$INPUT_VALUE" != "" ] && [ "$INPUT_VALUE" != "q" ]; then
            KAKFA_STORAGE_SIZE="$INPUT_VALUE"
        fi

        checkQuitInput $INPUT_VALUE

        printf "Zookeeper Storage Size [$ZOOKEEPER_STORAGE_SIZE]:"
        read INPUT_VALUE
        if [ "$INPUT_VALUE" != "" ] && [ "$INPUT_VALUE" != "q" ]; then
            ZOOKEEPER_STORAGE_SIZE="$INPUT_VALUE"
        fi

        checkQuitInput $INPUT_VALUE

        #if [ "$INPUT_VALUE" = "q" ]; then
        #    removeTempDirs
        #    exit 0
        #fi        
        INPUT_VALUE="q"
    done
}

function checkQuitInput(){
    local input=$1
    if [ "$input" = "q" ]; then
        removeTempDirs
        exit 0
    fi   
}

# Check if a resource exist in OCP
check_resource() {
  local kind=$1
  local name=$2
  oc get $kind $name -o name >/dev/null 2>&1
  if [ $? != 0 ]; then
    echo "false"
  else
    echo "true"
  fi
}

function printCmdUsage(){
    echo 
    echo "This is script to configure Prometheus and Grafana for JMeter on OpenShift."
    echo
    echo "Command usage: ./deploy.sh <options>"
    echo 
    echo "-h            Show complete help info."
    echo "-i            Deploy the environment for Kafka load testing."
    #echo "-j            Configure Prometheus and Grafana for JMeter."
    #echo "-k            Deploy Kafka cluster, and configure Prometheus & Grafana for Kafka."
    echo 
}

function printHelp(){
    printCmdUsage
    echo "This script is designed for OpenShift 4.5 and above."
    echo
    printHeader "Refer to the following website for the complete and updated guide ..."
    echo
    printLink "https://github.com/chengkuangan/jmeter-container"
    echo
}

function printResult(){
    echo 
    echo "=============================================================================================================="
    echo 
    printTitle "The Prometheus and Grafana environment is configured successfully for JMeter on OpenShift @ $APPS_NAMESPACE"
    echo
    echo "=============================================================================================================="
    echo
}

function processArguments(){

    if [ $# -eq 0 ]; then
        printCmdUsage
        exit 0
    fi

    while (( "$#" )); do
      if [ "$1" == "-h" ]; then
        printHelp
        exit 0
      # Proceed to install
      elif [ "$1" == "-i" ]; then
        PROCEED_INSTALL="yes"
        shift
      else
        echo "Unknown argument: $1"
        printCmdUsage
        exit 0
      fi
      shift
    done
}

function showConfirmToProceed(){
    echo
    printWarning "Press ENTER (OR Ctrl-C to cancel) to proceed..."
    read bc
}

processArguments $@
readInput
printVariables

if [ "$PROCEED_INSTALL" != "yes" ]; then
    removeTempDirs
    exit 0
fi

init
showConfirmToProceed
configurePrometheus
deployKafkaRelated
deployJMeterRelated
removeTempDirs
printResult