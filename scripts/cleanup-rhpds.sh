#!/bin/bash

# IMPORTANT: Run this script as system:admin

################################
# FUNCTIONS                    #
################################

function clean_up_existing_infra() {
  local _PROJECTS=
  # delete projects
  for i in `seq 0 100`; do
    if [ $i -lt 10 ]; then
      _PROJECTS+=" explore-0$i"
    else
      _PROJECTS+=" explore-$i"
    fi
  done

  echo "Deleting projects: $_PROJECTS"
  oc delete project $_PROJECTS

  # delete roadshow guides
  oc delete all -l app=labs -n lab-infra

  # delete gitlab
  oc delete all -l app=gitlab-ce -n lab-infra

  sudo sed -i "s/maxProjects: 1/maxProjects: 3/g" /etc/origin/master/master-config.yaml
  sudo systemctl restart atomic-openshift-master
}

function set_default_resource_limits() {
  rm -rf /tmp/project-template.yml
  cat <<EOF > /tmp/project-template.yml
apiVersion: v1
kind: Template
metadata:
  name: project-request
objects:
- apiVersion: v1
  kind: Project
  metadata:
    annotations:
      openshift.io/description: \${PROJECT_DESCRIPTION}
      openshift.io/display-name: \${PROJECT_DISPLAYNAME}
      openshift.io/requester: \${PROJECT_REQUESTING_USER}
    name: \${PROJECT_NAME}
  spec: {}
  status: {}
- apiVersion: v1
  kind: ResourceQuota
  metadata:
    name: \${PROJECT_NAME}-quota
  spec:
    hard:
      persistentvolumeclaims: "5"
      pods: 15
      requests.storage: 5Gi
      resourcequotas: 1
- apiVersion: v1
  kind: LimitRange
  metadata:
    creationTimestamp: null
    name: \${PROJECT_NAME}-limits
  spec:
    limits:
    - default:
        cpu: 2000m
        memory: 1048Mi
      defaultRequest:
        cpu: 100m
        memory: 512Mi
      max:
        cpu: 4000m
        memory: 2048Mi
      min:
        cpu: 50m
        memory: 50Mi
      type: Container
- apiVersion: v1
  groupNames:
  - system:serviceaccounts:\${PROJECT_NAME}
  kind: RoleBinding
  metadata:
    creationTimestamp: null
    name: system:image-pullers
    namespace: \${PROJECT_NAME}
  roleRef:
    name: system:image-puller
  subjects:
  - kind: SystemGroup
    name: system:serviceaccounts:\${PROJECT_NAME}
  userNames: null
- apiVersion: v1
  groupNames: null
  kind: RoleBinding
  metadata:
    creationTimestamp: null
    name: system:image-builders
    namespace: \${PROJECT_NAME}
  roleRef:
    name: system:image-builder
  subjects:
  - kind: ServiceAccount
    name: builder
  userNames:
  - system:serviceaccount:\${PROJECT_NAME}:builder
- apiVersion: v1
  groupNames: null
  kind: RoleBinding
  metadata:
    creationTimestamp: null
    name: system:deployers
    namespace: \${PROJECT_NAME}
  roleRef:
    name: system:deployer
  subjects:
  - kind: ServiceAccount
    name: deployer
  userNames:
  - system:serviceaccount:\${PROJECT_NAME}:deployer
- apiVersion: v1
  groupNames: null
  kind: RoleBinding
  metadata:
    creationTimestamp: null
    name: admin
    namespace: \${PROJECT_NAME}
  roleRef:
    name: admin
  subjects:
  - kind: User
    name: \${PROJECT_ADMIN_USER}
  userNames:
  - \${PROJECT_ADMIN_USER}
parameters:
- name: PROJECT_NAME
- name: PROJECT_DISPLAYNAME
- name: PROJECT_DESCRIPTION
- name: PROJECT_ADMIN_USER
- name: PROJECT_REQUESTING_USER
EOF

  oc delete template project-request -n default
  oc create -f /tmp/project-template.yml -n default
}

################################
# MAIN                         #
################################

clean_up_existing_infra;
set_default_resource_limits;
