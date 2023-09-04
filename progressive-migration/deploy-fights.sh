# In OCP4
oc apply -f ~/quarkus-superheroes-skupper/rest-fights/deploy/k8s/native-openshift-all-downstream.yml
skupper expose deploymentconfig rest-fights --address rest-fights --port 8082

