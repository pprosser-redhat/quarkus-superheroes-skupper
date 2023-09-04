oc apply -f ~/quarkus-superheroes-skupper/ui-super-heroes/deploy/k8s/native-openshift.yml
oc delete service rest-fights
oc expose service rest-fights

