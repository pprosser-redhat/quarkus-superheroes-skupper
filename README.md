oc # Superheroes and Skupper demo

## Introduction

The purpose of this demo is to show how easy it is to setup Skupper. I choose to use the Superheroes demo because its microservice architecure. It makes it very to use Skupper with.

The demo uses 2 OpenShift clusters, really doesn't matter which or where you deploy them. Clearly, the bigger the seperation, the more effective the demo is. I also use a local database running on my laptop.

Here is an architecture diagram of the application:
![Superheroes architecture diagram](images/application-architecture.png)

Here is how the distribution will be set up:
![Network distribution diagram](images/distribution.png)
I have chosen to split the villain service out on to a seperate cluster using Skupper and exposing the service. 

For the Heroes service.... I have hosted a mysql DB on my laptop that containes a table with the data in.

The demo will use a Skupper Gateway to expose the mysql DB to the Skupper Virutal application network.

Having exposed the database, Debezium is used to replicated the database, and then replicate changes to Kafka (either running on the OpenShift cluster, or usinf RHOSAK).

A small Camel K Integration will read the messages from Kafka and route them to the Postgres DB, allowing the full application to work.

## Setting up the Demo

### Deploy 2 OpenShift clusters

Choose one of the 2 clusters to host the Superheroes fight game. Typically choose the most public cluster if you have one.

I'm normally using AWS hosted and demolab

### Deploy the demo

Clone this repo so you can run the commands locally

#### Create the superheroes namespace in the public cluster

```
oc new-project superheroes
```

#### Deploy the application into the superheroes namespace

* clone the repository

  ```
  git clone https://github.com/pprosser-redhat/quarkus-super-heroes.git
  ```

* deploy the whole application into the superheroes namespace

   cd to the root of the cloned project

   ```
   oc apply -f deploy/k8s/native-java17-openshift.yml
   ```

   remove the villain service so it can be deployed in the other cluster

   ```
   oc delete all -l app.kubernetes.io/part-of=villains-service
   ```

* deploy the villain service to the 2nd OpenShift cluster

  oc to the second cluster

  create a new namespace 

  ```
  oc new-project villains
  ```

  deploy the villain service

  ```
  oc apply -f rest-villains/deploy/k8s/native-java17-kubernetes.yml
  ```

  Demo code should all now be deployed

# Demo Instructions

## Get the fight app up (URL will be different of course)

```
http://ui-super-heroes-superheroes.apps.rosa-zjs4n.tvaf.p1.openshiftapps.com/
```

## Clear demo Heroes

Make sure the hero data is deleted from the hero pod on rosa\

```
psql --dbname=heroes_database --username=superman --password
```
```
delete from hero;
```

## Initialise Skupper in each namespace

```
skupper init --site-name rosa --enable-console --enable-flow-collector --console-auth openshift
```
```
skupper init --site-name intel --enable-console --enable-flow-collector --console-auth openshift
```

## Link the sites together (most private to the most public)

Can do this in the consoles as well if you want 

In rosa window
```
skupper token create ~/rosa.yaml -t cert --name rosa
```
In intel window
```
skupper link create ~/rosa.yaml
```

## Expose  the villain service on the intel side

```
skupper expose deployment rest-villains --port 8084 --protocol http
```
Check the game, villains should start appearing.... might need to refresh the page.

## Get data from my laptop by defining a skupper gateway on the rosa node

```
skupper gateway init --type podman
```

## Expose my database

```
skupper gateway expose philsmysql 10.0.2.2 3306 --protocol tcp --type podman
```

Test that I can connect to to DB, in a mysql pod on either cluster

```
mysql --host=philsmysql --port 3306 --user=phil --password=phil
```
```
select id, name, othername from phil.hero;
```

## Setup debezium to capture data

### Kafka Cluster:
```
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: my-cluster
spec:
  entityOperator:
    topicOperator: {}
    userOperator: {}
  kafka:
    config:
      offsets.topic.replication.factor: 1
      transaction.state.log.replication.factor: 1
      transaction.state.log.min.isr: 1
      default.replication.factor: 1
      min.insync.replicas: 1
      inter.broker.protocol.version: '3.4'
      delete.topic.enabled: true
    listeners:
      - name: plain
        port: 9092
        tls: false
        type: internal
      - name: tls
        port: 9093
        tls: true
        type: internal
    replicas: 1
    storage:
      type: persistent-claim
      size: 1Gi
      deleteClaim: true
    metricsConfig:
      type: jmxPrometheusExporter
      valueFrom:
        configMapKeyRef:
          name: kafka-metrics
          key: kafka-metrics-config.yml
    version: 3.4.0
  zookeeper:
    replicas: 1
    storage:
      type: persistent-claim
      size: 1Gi
      deleteClaim: true
    metricsConfig:
      type: jmxPrometheusExporter
      valueFrom:
        configMapKeyRef:
          name: kafka-metrics
          key: zookeeper-metrics-config.yml
  kafkaExporter:
  topicRegex: ".*"
  groupRegex: ".*"

```
### Kafka Connect Cluster


Note: Make sure you create the imagestream. The build will just wait if you don't


```
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaConnect
metadata:
  name: my-connect-cluster
  annotations:
    strimzi.io/use-connector-resources: "true"
spec:
  bootstrapServers: 'my-cluster-kafka-bootstrap:9093'
  metricsConfig:
    type: jmxPrometheusExporter
    valueFrom:
      configMapKeyRef:
        name: connect-metrics
        key: metrics-config.yml
  replicas: 1
  config:
    group.id: connect-cluster
    offset.storage.topic: connect-cluster-offsets
    config.storage.topic: connect-cluster-configs
    status.storage.topic: connect-cluster-status
    config.storage.replication.factor: 1
    offset.storage.replication.factor: 1
    status.storage.replication.factor: 1
  tls:
    trustedCertificates:
      - certificate: ca.crt
        secretName: my-cluster-cluster-ca-cert
  version: 3.4.0
  build:
    output:
      type: imagestream
      image: debezium-connector-image:latest
    plugins:
      - name: debezium-mysql-connector
        artifacts:
          - type: zip
            url: https://maven.repository.redhat.com/ga/io/debezium/debezium-connector-mysql/2.1.4.Final-redhat-00001/debezium-connector-mysql-2.1.4.Final-redhat-00001-plugin.zip 
      - name: debezium-postgres-connector
        artifacts:
          - type: zip
            url: https://maven.repository.redhat.com/ga/io/debezium/debezium-connector-postgres/2.1.4.Final-redhat-00001/debezium-connector-postgres-2.1.4.Final-redhat-00001-plugin.zip
```
## Deploy the Kafka Connector

```
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaConnector
metadata:
  name: phils-connector  
  labels:
    strimzi.io/cluster: my-connect-cluster
spec:
  class: io.debezium.connector.mysql.MySqlConnector
  tasksMax: 1  
  config:
    snapshot.mode: when_needed
    database.hostname: philsmysql  
    database.port: 3306
    database.user: phil
    database.password: phil
    database.server.id: 18999  
    database.server.name: philsmac  
    database.whitelist: phil
    database.history.kafka.bootstrap.servers: my-cluster-kafka-bootstrap:9092  
    database.history.kafka.topic: schema-changes.phil
```

## Deploy the integration to replicate the data

```
kamel run camelkfordebezium/crudlegacyheroes.yaml
```

## To monitor the Kafka Topic

```
oc exec -it my-cluster-kafka-0 -- /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --from-beginning \
  --topic philsmac.phil.hero
```

## Terminal window. 

Create a terminal window like this:

![Terminal window layout](images/cli.png)

I have created an arrangement on my laptop to speed this up.

In the demolab window, type

```
export KUBECONFIG=$HOME/.kube/config-coffee
```

In the AWS ROSA window type 

```
export KUBECONFIG=$HOME/.kube/config-rosa
```

## Building in Kafka Monitoring into the demo if you want it 

Need to firstly enable OpenShift user project monitoring - follow docs

Next, need to deploy the Strimzi metrics configmap 

```
kind: ConfigMap
apiVersion: v1
metadata:
  name: kafka-metrics
  labels:
    app: strimzi
data:
  kafka-metrics-config.yml: |
    # See https://github.com/prometheus/jmx_exporter for more info about JMX Prometheus Exporter metrics
    lowercaseOutputName: true
    rules:
    # Special cases and very specific rules
    - pattern: kafka.server<type=(.+), name=(.+), clientId=(.+), topic=(.+), partition=(.*)><>Value
      name: kafka_server_$1_$2
      type: GAUGE
      labels:
       clientId: "$3"
       topic: "$4"
       partition: "$5"
    - pattern: kafka.server<type=(.+), name=(.+), clientId=(.+), brokerHost=(.+), brokerPort=(.+)><>Value
      name: kafka_server_$1_$2
      type: GAUGE
      labels:
       clientId: "$3"
       broker: "$4:$5"
    - pattern: kafka.server<type=(.+), cipher=(.+), protocol=(.+), listener=(.+), networkProcessor=(.+)><>connections
      name: kafka_server_$1_connections_tls_info
      type: GAUGE
      labels:
        cipher: "$2"
        protocol: "$3"
        listener: "$4"
        networkProcessor: "$5"
    - pattern: kafka.server<type=(.+), clientSoftwareName=(.+), clientSoftwareVersion=(.+), listener=(.+), networkProcessor=(.+)><>connections
      name: kafka_server_$1_connections_software
      type: GAUGE
      labels:
        clientSoftwareName: "$2"
        clientSoftwareVersion: "$3"
        listener: "$4"
        networkProcessor: "$5"
    - pattern: "kafka.server<type=(.+), listener=(.+), networkProcessor=(.+)><>(.+):"
      name: kafka_server_$1_$4
      type: GAUGE
      labels:
       listener: "$2"
       networkProcessor: "$3"
    - pattern: kafka.server<type=(.+), listener=(.+), networkProcessor=(.+)><>(.+)
      name: kafka_server_$1_$4
      type: GAUGE
      labels:
       listener: "$2"
       networkProcessor: "$3"
    # Some percent metrics use MeanRate attribute
    # Ex) kafka.server<type=(KafkaRequestHandlerPool), name=(RequestHandlerAvgIdlePercent)><>MeanRate
    - pattern: kafka.(\w+)<type=(.+), name=(.+)Percent\w*><>MeanRate
      name: kafka_$1_$2_$3_percent
      type: GAUGE
    # Generic gauges for percents
    - pattern: kafka.(\w+)<type=(.+), name=(.+)Percent\w*><>Value
      name: kafka_$1_$2_$3_percent
      type: GAUGE
    - pattern: kafka.(\w+)<type=(.+), name=(.+)Percent\w*, (.+)=(.+)><>Value
      name: kafka_$1_$2_$3_percent
      type: GAUGE
      labels:
        "$4": "$5"
    # Generic per-second counters with 0-2 key/value pairs
    - pattern: kafka.(\w+)<type=(.+), name=(.+)PerSec\w*, (.+)=(.+), (.+)=(.+)><>Count
      name: kafka_$1_$2_$3_total
      type: COUNTER
      labels:
        "$4": "$5"
        "$6": "$7"
    - pattern: kafka.(\w+)<type=(.+), name=(.+)PerSec\w*, (.+)=(.+)><>Count
      name: kafka_$1_$2_$3_total
      type: COUNTER
      labels:
        "$4": "$5"
    - pattern: kafka.(\w+)<type=(.+), name=(.+)PerSec\w*><>Count
      name: kafka_$1_$2_$3_total
      type: COUNTER
    # Generic gauges with 0-2 key/value pairs
    - pattern: kafka.(\w+)<type=(.+), name=(.+), (.+)=(.+), (.+)=(.+)><>Value
      name: kafka_$1_$2_$3
      type: GAUGE
      labels:
        "$4": "$5"
        "$6": "$7"
    - pattern: kafka.(\w+)<type=(.+), name=(.+), (.+)=(.+)><>Value
      name: kafka_$1_$2_$3
      type: GAUGE
      labels:
        "$4": "$5"
    - pattern: kafka.(\w+)<type=(.+), name=(.+)><>Value
      name: kafka_$1_$2_$3
      type: GAUGE
    # Emulate Prometheus 'Summary' metrics for the exported 'Histogram's.
    # Note that these are missing the '_sum' metric!
    - pattern: kafka.(\w+)<type=(.+), name=(.+), (.+)=(.+), (.+)=(.+)><>Count
      name: kafka_$1_$2_$3_count
      type: COUNTER
      labels:
        "$4": "$5"
        "$6": "$7"
    - pattern: kafka.(\w+)<type=(.+), name=(.+), (.+)=(.*), (.+)=(.+)><>(\d+)thPercentile
      name: kafka_$1_$2_$3
      type: GAUGE
      labels:
        "$4": "$5"
        "$6": "$7"
        quantile: "0.$8"
    - pattern: kafka.(\w+)<type=(.+), name=(.+), (.+)=(.+)><>Count
      name: kafka_$1_$2_$3_count
      type: COUNTER
      labels:
        "$4": "$5"
    - pattern: kafka.(\w+)<type=(.+), name=(.+), (.+)=(.*)><>(\d+)thPercentile
      name: kafka_$1_$2_$3
      type: GAUGE
      labels:
        "$4": "$5"
        quantile: "0.$6"
    - pattern: kafka.(\w+)<type=(.+), name=(.+)><>Count
      name: kafka_$1_$2_$3_count
      type: COUNTER
    - pattern: kafka.(\w+)<type=(.+), name=(.+)><>(\d+)thPercentile
      name: kafka_$1_$2_$3
      type: GAUGE
      labels:
        quantile: "0.$4"
  zookeeper-metrics-config.yml: |
    # See https://github.com/prometheus/jmx_exporter for more info about JMX Prometheus Exporter metrics
    lowercaseOutputName: true
    rules:
    # replicated Zookeeper
    - pattern: "org.apache.ZooKeeperService<name0=ReplicatedServer_id(\\d+)><>(\\w+)"
      name: "zookeeper_$2"
      type: GAUGE
    - pattern: "org.apache.ZooKeeperService<name0=ReplicatedServer_id(\\d+), name1=replica.(\\d+)><>(\\w+)"
      name: "zookeeper_$3"
      type: GAUGE
      labels:
        replicaId: "$2"
    - pattern: "org.apache.ZooKeeperService<name0=ReplicatedServer_id(\\d+), name1=replica.(\\d+), name2=(\\w+)><>(Packets\\w+)"
      name: "zookeeper_$4"
      type: COUNTER
      labels:
        replicaId: "$2"
        memberType: "$3"
    - pattern: "org.apache.ZooKeeperService<name0=ReplicatedServer_id(\\d+), name1=replica.(\\d+), name2=(\\w+)><>(\\w+)"
      name: "zookeeper_$4"
      type: GAUGE
      labels:
        replicaId: "$2"
        memberType: "$3"
    - pattern: "org.apache.ZooKeeperService<name0=ReplicatedServer_id(\\d+), name1=replica.(\\d+), name2=(\\w+), name3=(\\w+)><>(\\w+)"
      name: "zookeeper_$4_$5"
      type: GAUGE
      labels:
        replicaId: "$2"
        memberType: "$3"
```

# Kafka Connect Metrics

```
kind: ConfigMap
apiVersion: v1
metadata:
  name: connect-metrics
  labels:
    app: strimzi
data:
  metrics-config.yml: |
    # Inspired by kafka-connect rules
    # https://github.com/prometheus/jmx_exporter/blob/master/example_configs/kafka-connect.yml
    # See https://github.com/prometheus/jmx_exporter for more info about JMX Prometheus Exporter metrics
    lowercaseOutputName: true
    lowercaseOutputLabelNames: true
    rules:
    #kafka.connect:type=app-info,client-id="{clientid}"
    #kafka.consumer:type=app-info,client-id="{clientid}"
    #kafka.producer:type=app-info,client-id="{clientid}"
    - pattern: 'kafka.(.+)<type=app-info, client-id=(.+)><>start-time-ms'
      name: kafka_$1_start_time_seconds
      labels:
        clientId: "$2"
      help: "Kafka $1 JMX metric start time seconds"
      type: GAUGE
      valueFactor: 0.001
    - pattern: 'kafka.(.+)<type=app-info, client-id=(.+)><>(commit-id|version): (.+)'
      name: kafka_$1_$3_info
      value: 1
      labels:
        clientId: "$2"
        $3: "$4"
      help: "Kafka $1 JMX metric info version and commit-id"
      type: GAUGE

    #kafka.producer:type=producer-topic-metrics,client-id="{clientid}",topic="{topic}"", partition="{partition}"
    #kafka.consumer:type=consumer-fetch-manager-metrics,client-id="{clientid}",topic="{topic}"", partition="{partition}"
    - pattern: kafka.(.+)<type=(.+)-metrics, client-id=(.+), topic=(.+), partition=(.+)><>(.+-total|compression-rate|.+-avg|.+-replica|.+-lag|.+-lead)
      name: kafka_$2_$6
      labels:
        clientId: "$3"
        topic: "$4"
        partition: "$5"
      help: "Kafka $1 JMX metric type $2"
      type: GAUGE

    #kafka.producer:type=producer-topic-metrics,client-id="{clientid}",topic="{topic}"
    #kafka.consumer:type=consumer-fetch-manager-metrics,client-id="{clientid}",topic="{topic}"", partition="{partition}"
    - pattern: kafka.(.+)<type=(.+)-metrics, client-id=(.+), topic=(.+)><>(.+-total|compression-rate|.+-avg)
      name: kafka_$2_$5
      labels:
        clientId: "$3"
        topic: "$4"
      help: "Kafka $1 JMX metric type $2"
      type: GAUGE

    #kafka.connect:type=connect-node-metrics,client-id="{clientid}",node-id="{nodeid}"
    #kafka.consumer:type=consumer-node-metrics,client-id=consumer-1,node-id="{nodeid}"
    - pattern: kafka.(.+)<type=(.+)-metrics, client-id=(.+), node-id=(.+)><>(.+-total|.+-avg)
      name: kafka_$2_$5
      labels:
        clientId: "$3"
        nodeId: "$4"
      help: "Kafka $1 JMX metric type $2"
      type: UNTYPED

    #kafka.connect:type=kafka-metrics-count,client-id="{clientid}"
    #kafka.consumer:type=consumer-fetch-manager-metrics,client-id="{clientid}"
    #kafka.consumer:type=consumer-coordinator-metrics,client-id="{clientid}"
    #kafka.consumer:type=consumer-metrics,client-id="{clientid}"
    - pattern: kafka.(.+)<type=(.+)-metrics, client-id=(.*)><>(.+-total|.+-avg|.+-bytes|.+-count|.+-ratio|.+-age|.+-flight|.+-threads|.+-connectors|.+-tasks|.+-ago)
      name: kafka_$2_$4
      labels:
        clientId: "$3"
      help: "Kafka $1 JMX metric type $2"
      type: GAUGE

    #kafka.connect:type=connector-metrics,connector="{connector}"
    - pattern: 'kafka.(.+)<type=connector-metrics, connector=(.+)><>(connector-class|connector-type|connector-version|status): (.+)'
      name: kafka_connect_connector_$3
      value: 1
      labels:
        connector: "$2"
        $3: "$4"
      help: "Kafka Connect $3 JMX metric type connector"
      type: GAUGE

    #kafka.connect:type=connector-task-metrics,connector="{connector}",task="{task}<> status"
    - pattern: 'kafka.connect<type=connector-task-metrics, connector=(.+), task=(.+)><>status: ([a-z-]+)'
      name: kafka_connect_connector_task_status
      value: 1
      labels:
        connector: "$1"
        task: "$2"
        status: "$3"
      help: "Kafka Connect JMX Connector task status"
      type: GAUGE

    #kafka.connect:type=task-error-metrics,connector="{connector}",task="{task}"
    #kafka.connect:type=source-task-metrics,connector="{connector}",task="{task}"
    #kafka.connect:type=sink-task-metrics,connector="{connector}",task="{task}"
    #kafka.connect:type=connector-task-metrics,connector="{connector}",task="{task}"
    - pattern: kafka.connect<type=(.+)-metrics, connector=(.+), task=(.+)><>(.+-total|.+-count|.+-ms|.+-ratio|.+-seq-no|.+-rate|.+-max|.+-avg|.+-failures|.+-requests|.+-timestamp|.+-logged|.+-errors|.+-retries|.+-skipped)
      name: kafka_connect_$1_$4
      labels:
        connector: "$2"
        task: "$3"
      help: "Kafka Connect JMX metric type $1"
      type: GAUGE

    #kafka.connect:type=connector-metrics,connector="{connector}"
    #kafka.connect:type=connect-worker-metrics,connector="{connector}"
    - pattern: kafka.connect<type=connect-worker-metrics, connector=(.+)><>([a-z-]+)
      name: kafka_connect_worker_$2
      labels:
        connector: "$1"
      help: "Kafka Connect JMX metric $1"
      type: GAUGE

    #kafka.connect:type=connect-worker-metrics
    - pattern: kafka.connect<type=connect-worker-metrics><>([a-z-]+)
      name: kafka_connect_worker_$1
      help: "Kafka Connect JMX metric worker"
      type: GAUGE

    #kafka.connect:type=connect-worker-rebalance-metrics
    - pattern: kafka.connect<type=connect-worker-rebalance-metrics><>([a-z-]+)
      name: kafka_connect_worker_rebalance_$1
      help: "Kafka Connect JMX metric rebalance information"
      type: GAUGE
```
