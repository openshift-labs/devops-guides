# DevOps Workshop on OpenShift [![Build Status](https://travis-ci.org/openshift-labs/devops-guides.svg?branch=ocp-3.9)](https://travis-ci.org/openshift-labs/devops-guides)

The DevOps Workshop provides full-stack and DevOps engineers an introduction to OpenShift and containers and how it can be used to build fully automated end-to-end deployment pipelines using advanced deployments techniques like rolling deploys and blue-green deployment.

The lab application used in this workshop is available at https://github.com/openshift-labs/devops-labs

## Agenda
* DevOps Introduction
* Explore OpenShift
* Deployment Environments
* Creating a Simple CI/CD Pipeline
* Pipeline Definition as Code
* Application Promotion Between Environments
* Running the CI/CD Pipeline on Every Change
* Zero-Downtime Deployment to Production
* Automated Zero-Downtime Deployment with CI/CD Pipelines
* Deploying Jenkins Manually
* Creating Custom Jenkins Slave Pods



## Install Workshop Infrastructure

An [APB](https://hub.docker.com/r/openshiftapb/cloudnative-workshop-apb) is provided for 
deploying the Cloud-Native Workshop infra (lab instructions, Nexus, Gogs, Eclipse Che, etc) in a project 
on an OpenShift cluster via the service catalog. In order to add this APB to the OpenShift service catalog, log in 
as cluster admin and perform the following in the `openshift-ansible-service-broker` project :

1. Edit the `broker-config` configmap and add this snippet right after `registry:`:

  ```
    - name: dh
      type: dockerhub
      org: openshiftapb
      tag: ocp-3.9
      white_list: [.*-apb$]
  ```

2. Redeploy the `asb` deployment

You can [read more in the docs](https://docs.openshift.com/container-platform/3.9/install_config/oab_broker_configuration.html#oab-config-registry-dockerhub) 
on how to configure the service catalog.

Note that if you are using the _OpenShift Workshop_ in RHPDS, this APB is already available in your service catalog.

![](images/service-catalog.png?raw=true)

As an alternative, you can also run the APB directly in a pod on OpenShift to install the workshop infra:

```
oc login
oc new-project lab-infra
oc run apb --restart=Never --image="openshiftapb/devops-workshop-apb:ocp-3.9" \
    -- provision -vvv -e namespace=$(oc project -q) -e openshift_token=$(oc whoami -t)

```

## Lab Instructions on OpenShift

Note that if you have used the above workshop installer, the lab instructions are already deployed.

```
oc new-app osevg/workshopper:latest --name=guides \
    -e CONTENT_URL_PREFIX=https://raw.githubusercontent.com/openshift-labs/devops-guides/ocp-3.9 \
    -e WORKSHOPS_URLS=https://raw.githubusercontent.com/openshift-labs/devops-guides/ocp-3.9/_devops-workshop.yml
oc expose svc/guides
```

## Local Lab Instructions

```
docker run -p 8080:8080 \
              -v /path/to/clone/dir:/app-data \
              -e CONTENT_URL_PREFIX="file:///app-data" \
              -e WORKSHOPS_URLS="file:///app-data/_devops-workshop" \
              osevg/workshopper:latest
```