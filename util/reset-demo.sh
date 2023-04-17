oc delete application kitchensink-basic-app -n openshift-gitops
oc delete application kitchensink-helm-app -n openshift-gitops
oc delete applicationset kitchensink-basic -n openshift-gitops
oc delete applicationset kitchensink-kustomize -n openshift-gitops
oc delete applicationset kitchensink-kustomized-helm -n openshift-gitops
oc delete project demo-1
oc delete project demo-2
oc delete project demo-3
oc delete project demo-4a
oc delete project demo-4b
oc delete project demo-5-dev
oc delete project demo-5-test
oc delete project demo-6
oc delete project demo-7-dev
oc delete project demo-7-test