oc delete all -l application=fights-service
oc delete all -l application=event-stats
oc expose service rest-fights