oc create is debezium-connector-image
oc apply -f kafka-metrics.yaml
oc apply -f KafkaConnectMetrics.yaml
oc apply -f my-cluster.yaml
oc apply -f my-kafka-connect.yaml
# oc apply -f kafka-connector.yaml