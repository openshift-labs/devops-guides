# DevOps Workshop on OpenShift

The DevOps Workshop provides full-stack and DevOps engineers an introduction to OpenShift and containers and how it can be used to build fully automated end-to-end deployment pipelines using advanced deployments techniques like rolling deploys and blue-green deployment.

The lab application used in this workshop is available at https://github.com/openshift-roadshow/devops-workshop-labs

# Agenda
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

# Prepare Workshop

The provided script `setup-workshop.sh` prepares an OpenShift 3.5+ cluster for running the DevOps workshop 
by deploy the lab guides, Gogs server, Nexus, creating Git repositories, etc. 

```
$ oc login -u system:admin
$ bash <(curl -sL https://raw.githubusercontent.com/openshift-roadshow/devops-workshop-guides/master/scripts/setup-workshop.sh)
```

NOTE: This script assumes there are a number of OpenShift users generated on the cluster with 
the format `user00, user01, ...` and `openshift3` as password.