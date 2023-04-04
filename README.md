# Install ArgoCD and Pipelines using Red Hat Advanced Cluster Management for Kubernetes (ACM)

Red Hat Advanced Cluster Management for Kubernetes provides end-to-end management visibility and control to manage your Kubernetes environment. Take control of your application modernization program with management capabilities for cluster creation, application lifecycle, and provide security and compliance for all of them across data centers and hybrid cloud environments. Clusters and applications are all visible and managed from a single console, with built-in security policies. Run your operations from anywhere that Red Hat OpenShift runs, and manage any Kubernetes cluster in your fleet.

If you have already deployed an instance of ACM or you want to [install](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/2.3/html/install/index) it and leverage the Governance, Risk, and Compliance (GRC) super powers for this demo, use this [policies](rhacm) to get the operators installed automatically in your behalf.

# Install ArgoCD, Pipelines and Quay using the operators

Install ArgoCD Operator, Openshift Pipelines and Quay (simplified non-supported configuration):

```sh
until oc apply -k util/bootstrap/; do sleep 2; done
```

# Migrate from github

Let's prepare some environment variables:

```sh
export GIT_REVISION=main

# Gitea
export GIT_USERNAME=gitea
export GIT_PASSWORD=openshift

export GIT_CONF_REPONAME=kitchensink-conf
export KITCHENSINK_REPO_NAME=kitchensink

# Source Repo to Migrate from
export GIT_USERNAME_SRC=cvicens
export GIT_URL_BASE_SRC=https://github.com/atarazana
export GIT_URL_KITCHENSINK_SRC=${GIT_URL_BASE_SRC}/${KITCHENSINK_REPO_NAME}
export GIT_CONF_URL_SRC=${GIT_URL_BASE_SRC}/${GIT_CONF_REPONAME}
```

We need some sensitive data, your PAT for the source repo:

```sh
export GIT_HOST=$(oc get route/repository -n gitea-system -o jsonpath='{.spec.host}')

export GIT_PAT=$(curl -k -s -X 'POST' -H "Content-Type: application/json"  -k -d '{"name":"cicd'"${RANDOM}"'", "scopes":["repo"]}' -u ${GIT_USERNAME}:${GIT_PASSWORD} https://${GIT_HOST}/api/v1/users/${GIT_USERNAME}/tokens | jq -r .sha1)

echo "GIT_PAT=${GIT_PAT}"
```

Now that we have a PAT we can use it to log in as and import the repositories containing both code and configuration, namely:\

- **Configuration:** https://github.com/atarazana/kitchensink-conf
- **Kitchensink Service:** https://github.com/atarazana/kitchensink

Run the following command to import these git repositories into Gitea.

```sh
curl -X 'POST' \
  "https://${GIT_HOST}/api/v1/repos/migrate?token=${GIT_PAT}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "auth_password": "'${GIT_PASSWORD_SRC}'",
  "auth_username": "'${GIT_USERNAME_SRC}'",
  "clone_addr": "'${GIT_CONF_URL_SRC}'.git",
  "description": "kitchensink conf",
  "issues": false,
  "labels": false,
  "lfs": false,
  "milestones": false,
  "private": true,
  "pull_requests": false,
  "releases": false,
  "repo_name": "'${GIT_CONF_REPONAME}'",
  "repo_owner": "'${GIT_USERNAME}'",
  "service": "git",
  "wiki": false
}'

curl -X 'POST' \
  "https://${GIT_HOST}/api/v1/repos/migrate?token=${GIT_PAT}" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "auth_password": "'${GIT_PASSWORD_SRC}'",
  "auth_username": "'${GIT_USERNAME_SRC}'",
  "clone_addr": "'${GIT_URL_KITCHENSINK_SRC}'.git",
  "description": "gramola events",
  "issues": false,
  "labels": false,
  "lfs": false,
  "milestones": false,
  "private": true,
  "pull_requests": false,
  "releases": false,
  "repo_name": "'${KITCHENSINK_REPO_NAME}'",
  "repo_owner": "'${GIT_USERNAME}'",
  "service": "git",
  "wiki": false
}'

```

# Log in ArgoCD with CLI

Use `argocd` cli to log in the OpenShift cluster:

```sh
export ARGOCD_HOST=$(oc get route/openshift-gitops-server -o jsonpath='{.status.ingress[0].host}' -n openshift-gitops)

export ARGOCD_USERNAME=admin
export ARGOCD_PASSWORD=$(oc get secret openshift-gitops-cluster -o jsonpath='{.data.admin\.password}' -n openshift-gitops | base64 -d)

argocd login $ARGOCD_HOST --insecure --grpc-web --username $ARGOCD_USERNAME --password $ARGOCD_PASSWORD
```

**NOTE:** You will use the OpenShift SSO to log in the web console.

# Register repos

In this guide we cover the case of a protected git repositories that's why you need to create a Personal Access Token so that you don't have to expose your personal account.

You can find an easy guide step by step by following this link: [Creating a personal access token - GitHub Docs](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)

NOTE: We're covering Github in this guide if you use a different git server you may have to do some adjustments.

In order to refer to a repository in ArgoCD you have to register it before, the next command will do this for you asking for the repo url and the the Personal Access Token (PAT) to access to the repository. 


```sh
argocd repo add https://${GIT_HOST}/${GIT_USERNAME}/${GIT_CONF_REPONAME}.git --username ${GIT_USERNAME} --password ${GIT_PAT} --upsert --grpc-web --insecure --insecure-skip-server-verification
```

Run this command to list the registered repositories.

```sh
argocd repo list --grpc-web --insecure
```

# Register additional clusters

First make sure there is a context with proper credentials, in order to achieve this please log in the additional cluster.

```sh
export API_USER=opentlc-mgr
export API_SERVER_MANAGED=api.example.com:6443
oc login --server=https://${API_SERVER_MANAGED} -u ${API_USER} --insecure-skip-tls-verify
```

Give a name to the additional cluster and add it with the next command.

**CAUTION:** **CLUSTER_NAME** is a name you choose for your cluster, **API_SERVER** is the host and port **without `http(s)`**.

```sh
export CLUSTER_NAME=aws-managed1
CONTEXT_NAME=$(oc config get-contexts -o name | grep ${API_SERVER_MANAGED})

argocd cluster add ${CONTEXT_NAME} --name ${CLUSTER_NAME}
```

Check if your cluster has been added correctly.

```sh
argocd cluster list --grpc-web --insecure
```

# List ArgoCD Project definitions

**IMPORTANT:** Now you have to log back in the cluster where ArgoCD is running.

```sh
argocd proj list --grpc-web --insecure
```

# Create Root Apps

Let's deploy all the components of Gramola using an `ApplicationSet`.

```sh
cat <<EOF | kubectl apply -n openshift-gitops -f -
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: kitchensink-kustomized-helm
  namespace: openshift-gitops
  labels:
    argocd-root-app: "true"
spec:
  generators:
  - list:
      elements:
      - env: dev
        ns: demo-7-dev
        desc: "Demo 7 Dev"
      - env: test
        ns: demo-7-test
        desc: "Demo 7 Test"
  template:
    metadata:
      name: kitchensink-kustomized-helm-app-{{ env }}
      namespace: openshift-gitops
      labels:
        kitchensink-root-app: "true"
      finalizers:
      - resources-finalizer.argocd.argoproj.io
    spec:
      destination:
        namespace: '{{ ns }}'
        name: in-cluster
      ignoreDifferences:
      - group: apps.openshift.io
        kind: DeploymentConfig
        jqPathExpressions:
          - .spec.template.spec.containers[].image
      project: kitchensink-project-{{ env }}
      syncPolicy:
        automated:
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
      source:
        path: advanced/overlays/{{ env }}
        repoURL: "https://${GIT_HOST}/${GIT_USERNAME}/${GIT_CONF_REPONAME}"
        targetRevision: ${GIT_REVISION}
        plugin:
          env:
            - name: DEBUG
              value: 'false'
            - name: BASE_NAMESPACE
              value: '{{ ns }}'
          name: kustomized-helm
EOF
```

If an additional cluster has been set up:

```sh
cat <<EOF | kubectl apply -n openshift-gitops -f -
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: kitchensink-kustomized-helm-cloud
  namespace: openshift-gitops
  labels:
    argocd-root-app: "true"
spec:
  generators:
  - list:
      elements:
      - env: test-cloud
        ns: demo-7-test
        desc: "Demo 7 Test Cloud"
  template:
    metadata:
      name: kitchensink-kustomized-helm-app-{{ env }}
      namespace: openshift-gitops
      labels:
        kitchensink-root-app: "true"
      finalizers:
      - resources-finalizer.argocd.argoproj.io
    spec:
      destination:
        namespace: '{{ ns }}'
        name: in-cluster
      ignoreDifferences:
      - group: apps.openshift.io
        kind: DeploymentConfig
        jqPathExpressions:
          - .spec.template.spec.containers[].image
      project: default
      syncPolicy:
        automated:
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
      source:
        path: advanced/overlays/{{ env }}
        repoURL: "https://${GIT_HOST}/${GIT_USERNAME}/${GIT_CONF_REPONAME}"
        targetRevision: ${GIT_REVISION}
        plugin:
          env:
            - name: DEBUG
              value: 'false'
            - name: BASE_NAMESPACE
              value: '{{ ns }}'
          name: kustomized-helm
EOF
```

# Create a robot account in Quay

Execute the next command to open Quay web console:

Linux

```sh
xdg-open "https://$(oc get route/myregistry-quay -n quay-system -o jsonpath='{.spec.host}')"
```

MacOS

```sh
open "https://$(oc get route/myregistry-quay -n quay-system -o jsonpath='{.spec.host}')"
```

Others, use the following command to get the server and point a browser to it using `https`.

```sh
oc get route/myregistry-quay -n quay-system -o jsonpath='{.spec.host}'
```

Log in with user `demos` and password `openshift`

The create a robot account named `cicd` and create repository `demos`.

# Tekton Pipelines

Next command sets the environment variables to set the secret so that Tekton pipelines can push images to the image registry.

```sh
export CONTAINER_REGISTRY_SERVER=$(oc get route/myregistry-quay -n quay-system -o jsonpath='{.spec.host}')
export CONTAINER_REGISTRY_ORG=demos
export CONTAINER_REGISTRY_USERNAME="demos+cicd"
```

Deploy another ArgoCD app to deploy pipelines.

```sh
cat <<EOF | kubectl apply -n openshift-gitops -f -
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: kitchensink-cicd
  namespace: openshift-gitops
  labels:
    argocd-root-app: "true"
spec:
  generators:
  - list:
      elements:
      - cluster: in-cluster
        ns: openshift-gitops
  template:
    metadata:
      name: kitchensink-cicd
      namespace: openshift-gitops
      labels:
        argocd-root-app-cloud: "true"
      finalizers:
      - resources-finalizer.argocd.argoproj.io
    spec:
      destination:
        namespace: '{{ ns }}'
        name: '{{ cluster }}'
      project: default
      syncPolicy:
        automated:
          selfHeal: true
      source:
        helm:
          parameters:
            - name: baseRepoUrl
              value: "https://${GIT_HOST}/${GIT_USERNAME}/${GIT_CONF_REPONAME}"
            - name: username
              value: "${GIT_USERNAME}"
            - name: gitRevision
              value: "${GIT_REVISION}"
            - name: containerRegistryServer
              value: ${CONTAINER_REGISTRY_SERVER}
            - name: containerRegistryOrg
              value: ${CONTAINER_REGISTRY_ORG}
            - name: gitSslVerify
              value: "true"
        path: cicd
        repoURL: "https://${GIT_HOST}/${GIT_USERNAME}/${GIT_CONF_REPONAME}"
        targetRevision: ${GIT_REVISION}
EOF
```

If github is used...

```sh
cat <<EOF | kubectl apply -n openshift-gitops -f -
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: kitchensink-cicd
  namespace: openshift-gitops
  labels:
    argocd-root-app: "true"
spec:
  generators:
  - list:
      elements:
      - cluster: in-cluster
        ns: openshift-gitops
  template:
    metadata:
      name: kitchensink-cicd
      namespace: openshift-gitops
      labels:
        argocd-root-app-cloud: "true"
      finalizers:
      - resources-finalizer.argocd.argoproj.io
    spec:
      destination:
        namespace: '{{ ns }}'
        name: '{{ cluster }}'
      project: default
      syncPolicy:
        automated:
          selfHeal: true
      source:
        helm:
          parameters:
            - name: baseRepoUrl
              value: "${GIT_CONF_URL_SRC}"
            - name: username
              value: "${GIT_USERNAME_SRC}"
            - name: gitRevision
              value: "${GIT_REVISION}"
            - name: containerRegistryServer
              value: ${CONTAINER_REGISTRY_SERVER}
            - name: containerRegistryOrg
              value: ${CONTAINER_REGISTRY_ORG}
            - name: gitSslVerify
              value: "true"
        path: cicd
        repoURL: "${GIT_CONF_URL_SRC}"
        targetRevision: ${GIT_REVISION}
EOF
```

We are going to create secrets instead of storing then in the git repo, but before we do let's check that ArgoCD has created the namespace for us.

```sh
export CICD_NAMESPACE=$(yq eval '.cicdNamespace' ./cicd/values.yaml)
```

NOTE: If the namespace is not there yet, you can check the sync status of the ArgoCD application with: `argocd app sync kitchensink-cicd-app`

```sh
oc get project ${CICD_NAMESPACE}
```

Once the namespace is created you can create the secrets. This commands will ask you for the PAT again, this time to create a secret with it.

```sh
./cicd/create-git-secret.sh ${CICD_NAMESPACE} ${GIT_HOST} ${GIT_USERNAME} ${GIT_PAT}
```

Now please run this command, it will ask for the password of the robot account you created before, so go to the quay console and copy it in the clipboard and paste it in your terminal.

```sh
echo "Enter password for ${CONTAINER_REGISTRY_USERNAME}: " && read -s CONTAINER_REGISTRY_PASSWORD
```

```sh
echo "Password entered: ${CONTAINER_REGISTRY_PASSWORD}"
```

Create the secret with the user and password.

```sh
./cicd/create-registry-secret.sh ${CICD_NAMESPACE} ${CONTAINER_REGISTRY_SERVER} ${CONTAINER_REGISTRY_ORG} ${CONTAINER_REGISTRY_USERNAME} ${CONTAINER_REGISTRY_PASSWORD}
```

# Add a Secret to pull images from the Quay installation

In order to pull images from the deployment of Quay in project `quay-system` run this command that creates secrets with credentials to be used in `gramola-dev` and `gramola-test`. Then the secrets are linked to the default service account for `pulling` images.

```sh
export CONTAINER_REGISTRY_SECRET_NAME=$(yq eval '.containerRegistrySecretName' ./cicd/values.yaml)

if [ -z "${CONTAINER_REGISTRY_USERNAME}" ] && [ -z "${CONTAINER_REGISTRY_PASSWORD}" ]; then
    echo "You should provide a value for CONTAINER_REGISTRY_USERNAME and CONTAINER_REGISTRY_PASSWORD"
else
oc create -n demo-7-dev secret docker-registry ${CONTAINER_REGISTRY_SECRET_NAME} \
  --docker-server=https://${CONTAINER_REGISTRY_SERVER} \
  --docker-username=${CONTAINER_REGISTRY_USERNAME} \
  --docker-password=${CONTAINER_REGISTRY_PASSWORD}
oc secrets link default ${CONTAINER_REGISTRY_SECRET_NAME} --for=pull -n demo-7-dev
oc create -n demo-7-test secret docker-registry ${CONTAINER_REGISTRY_SECRET_NAME} \
  --docker-server=https://${CONTAINER_REGISTRY_SERVER} \
  --docker-username=${CONTAINER_REGISTRY_USERNAME} \
  --docker-password=${CONTAINER_REGISTRY_PASSWORD}
oc secrets link default ${CONTAINER_REGISTRY_SECRET_NAME} --for=pull -n demo-7-test
fi
```

If there's an additional cluster... there you have to do the same... don't forget to log back in the main cluster.

```sh
export ADDITIONAL_API_SERVER_TOKEN=sha256~Ka7SHU9_Yd4_2OFSIWu1GqM5unovT3PMT8W4h0u7v7Y
export ADDITIONAL_API_SERVER_MANAGED=api.cluster-zmjd7.zmjd7.sandbox1118.opentlc.com:6443
oc login --token=${ADDITIONAL_API_SERVER_TOKEN} --server=https://${ADDITIONAL_API_SERVER_MANAGED}

export CONTAINER_REGISTRY_SECRET_NAME=$(yq eval '.containerRegistrySecretName' ./cicd/values.yaml)

if [ -z "${CONTAINER_REGISTRY_USERNAME}" ] && [ -z "${CONTAINER_REGISTRY_PASSWORD}" ]; then
    echo "You should provide a value for CONTAINER_REGISTRY_USERNAME and CONTAINER_REGISTRY_PASSWORD"
else
oc create -n demo-7-test secret docker-registry ${CONTAINER_REGISTRY_SECRET_NAME} \
  --docker-server=https://$CONTAINER_REGISTRY_SERVER \
  --docker-username=$CONTAINER_REGISTRY_USERNAME \
  --docker-password=$CONTAINER_REGISTRY_PASSWORD
oc secrets link default ${CONTAINER_REGISTRY_SECRET_NAME} --for=pull -n demo-7-test
fi

oc login -u opentlc-mgr -p r3dh4t1! --server=https://api.cluster-rhpr5.rhpr5.sandbox2409.opentlc.com:6443
```

## Creating Web Hooks

Run the next command to create the webhooks for CI part of the Tekton pipelines.

```sh
KITCHENSINK_CI_EL_LISTENER_HOST=$(oc get route/el-kitchensink-ci-pl-push-gitea-listener -n ${CICD_NAMESPACE} -o jsonpath='{.spec.host}')

curl -k -X 'POST' "https://${GIT_HOST}/api/v1/repos/${GIT_USERNAME}/${KITCHENSINK_REPO_NAME}/hooks" \
  -H "accept: application/json" \
  -H "Authorization: token ${GIT_PAT}" \
  -H "Content-Type: application/json" \
  -d '{
  "active": true,
  "branch_filter": "*",
  "config": {
     "content_type": "json",
     "url": "http://'"${KITCHENSINK_CI_EL_LISTENER_HOST}"'"
  },
  "events": [
    "push" 
  ],
  "type": "gitea"
}'
```

And, run the next command to create the webhooks for CD part of the Tekton pipelines.

```sh
KITCHENSINK_CD_EL_LISTENER_HOST=$(oc get route/el-kitchensink-cd-pl-pr-gitea-listener  -n ${CICD_NAMESPACE} -o jsonpath='{.spec.host}')

curl -k -X 'POST' "https://${GIT_HOST}/api/v1/repos/${GIT_USERNAME}/${GIT_CONF_REPONAME}/hooks" \
  -H "accept: application/json" \
  -H "Authorization: token ${GIT_PAT}" \
  -H "Content-Type: application/json" \
  -d '{
  "active": true,
  "branch_filter": "*",
  "config": {
     "content_type": "json",
     "url": "http://'"${KITCHENSINK_CD_EL_LISTENER_HOST}"'"
  },
  "events": [
    "pull_request" 
  ],
  "type": "gitea"
}'
```

# Jenkins Pipelines

Deploy another ArgoCD app to deploy jenkins pipelines.

```sh
cat <<EOF | oc apply -n openshift-gitops -f -
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: kitchensink-cicd-jenkins
  namespace: openshift-gitops
  labels:
    argocd-root-app: "true"
spec:
  generators:
  - list:
      elements:
      - cluster: in-cluster
        ns: openshift-gitops
  template:
    metadata:
      name: kitchensink-cicd-jenkins
      namespace: openshift-gitops
      labels:
        argocd-root-app-cloud: "true"
      finalizers:
      - resources-finalizer.argocd.argoproj.io
    spec:
      destination:
        namespace: '{{ ns }}'
        name: '{{ cluster }}'
      project: default
      syncPolicy:
        automated:
          selfHeal: true
      source:
        helm:
          parameters:
            - name: gitUrl
              value: "https://${GIT_HOST}"
            - name: gitUsername
              value: "${GIT_USERNAME}"
            - name: baseRepoName
              value: "${GIT_CONF_REPONAME}"
            - name: gitRevision
              value: "${GIT_REVISION}"
            #- name: destinationName
            #  value: ${CLUSTER_NAME}
            - name: containerRegistryServer
              value: ${CONTAINER_REGISTRY_SERVER}
            - name: containerRegistryOrg
              value: ${CONTAINER_REGISTRY_ORG}
            - name: proxyEnabled
              value: 'false'
            - name: pipelineClusterName
              value: ''
            - name: pipelineCredentials
              value: ''
        path: apps/cicd-jenkins
        repoURL: "https://${GIT_HOST}/${GIT_USERNAME}/${GIT_CONF_REPONAME}"
        targetRevision: ${GIT_REVISION}
EOF
```

We are going to create secrets instead of storing then in the git repo, but before we do let's check that ArgoCD has created the namespace for us.

```sh
export JENKINS_NAMESPACE=$(yq eval '.jenkinsNamespace' ./cicd-jenkins/values.yaml)
```

NOTE: If the namespace is not there yet, you can check the sync status of the ArgoCD application with: `argocd app sync kitchensink-cicd-jenkins`

```sh
oc get project ${JENKINS_NAMESPACE}
```

Once the namespace is created you can create the secret for the git repository.

```sh
./cicd-jenkins/create-git-secret.sh ${JENKINS_NAMESPACE} ${GIT_HOST} ${GIT_USERNAME} ${GIT_PAT}
```

In the same fashion, with this command you will create the secret to interact with the quay registry.

```sh
./cicd-jenkins/create-registry-secret.sh ${JENKINS_NAMESPACE} ${CONTAINER_REGISTRY_SERVER} ${CONTAINER_REGISTRY_ORG} ${CONTAINER_REGISTRY_USERNAME} ${CONTAINER_REGISTRY_PASSWORD}
```

## Creating Web Hooks

Before you can create the webhooks for the Jenkins pipeline let's add a trigger to the pipelines with the next command.

```sh
oc set triggers bc/gramola-events-pipeline --from-webhook -n ${JENKINS_NAMESPACE}
export GIT_WEBHOOK_SECRET_KITCHENSINK=$(oc get bc/gramola-events-pipeline -o jsonpath={.spec.triggers[0].generic.secret} -n ${JENKINS_NAMESPACE})

oc set triggers bc/gramola-gateway-pipeline --from-webhook -n ${JENKINS_NAMESPACE}
export GIT_WEBHOOK_SECRET_GATEWAY=$(oc get bc/gramola-gateway-pipeline -o jsonpath={.spec.triggers[0].generic.secret} -n ${JENKINS_NAMESPACE})
```

Execute this command to get the URL of the Webhook listener.

```sh
export API_SERVER=https://kubernetes.default.svc

export KITCHENSINK_CI_BC_WEBHOOK_URL="${API_SERVER}/apis/build.openshift.io/v1/namespaces/${JENKINS_NAMESPACE}/buildconfigs/gramola-events-pipeline/webhooks/${GIT_WEBHOOK_SECRET_KITCHENSINK}/generic"

export GATEWAY_CI_BC_WEBHOOK_URL="${API_SERVER}/apis/build.openshift.io/v1/namespaces/${JENKINS_NAMESPACE}/buildconfigs/gramola-gateway-pipeline/webhooks/${GIT_WEBHOOK_SECRET_GATEWAY}/generic"
```

Finally let's create the webhook to trigger the Jenkins pipeline you have already deployed with ArgoCD.

```sh
curl -k -X 'POST' "https://${GIT_HOST}/api/v1/repos/${GIT_USERNAME}/gramola-events/hooks" \
  -H "accept: application/json" \
  -H "Authorization: token ${GIT_PAT}" \
  -H "Content-Type: application/json" \
  -d '{
  "active": true,
  "branch_filter": "*",
  "config": {
     "content_type": "json",
     "url": "'"${KITCHENSINK_CI_BC_WEBHOOK_URL}"'"
  },
  "events": [
    "push" 
  ],
  "type": "gitea"
}'

curl -k -X 'POST' "https://${GIT_HOST}/api/v1/repos/${GIT_USERNAME}/gramola-gateway/hooks" \
  -H "accept: application/json" \
  -H "Authorization: token ${GIT_PAT}" \
  -H "Content-Type: application/json" \
  -d '{
  "active": true,
  "branch_filter": "*",
  "config": {
     "content_type": "json",
     "url": "'"${GATEWAY_CI_BC_WEBHOOK_URL}"'"
  },
  "events": [
    "push" 
  ],
  "type": "gitea"
}'
```

# Trigger Jenkins Slave build

```sh
oc start-build bc/jenkins-agent-maven-gitops-bc -n ${JENKINS_NAMESPACE} 
```

# Useful commands

# Sync Root Apps alone

```sh
argocd app sync gramola-root-app-dev
argocd app sync gramola-root-app-test
argocd app sync gramola-root-app-test-cloud
```

# Sync apps manually

```sh
argocd app sync economiacircular-app-dev
argocd app sync economiacircular-app-test
argocd app sync economiacircular-app-test-cloud
```

# Sync children apps (app of apps)

```sh
argocd app sync -l app.kubernetes.io/instance=gramola-root-app
argocd app sync -l app.kubernetes.io/instance=gramola-root-app-dev
argocd app sync -l app.kubernetes.io/instance=gramola-root-app-test
argocd app sync -l app.kubernetes.io/instance=gramola-root-app-test-cloud
```

# AUX
git clone https://oauth2:1AbCDeF_g2HIJKLMNOPqr@gitlab.com/yourusername/project.git project
