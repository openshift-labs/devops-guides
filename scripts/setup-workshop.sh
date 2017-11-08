#!/bin/bash

function usage() {
    echo
    echo "Usage:"
    echo " $0 [command] [options]"
    echo " $0 --help"
    echo
    echo "Example:"
    echo " oc login -u system:admin"
    echo " $0 prepare --gogs-user-count 100"
    echo " $0 cleanup --gogs-user-count 100"
    echo
    echo "COMMANDS:"
    echo "   prepare        Prepare OpenShift cluster for the DevOps workshop. Default"
    echo "   cleanup        Clean up the OpenShift cluster"
    echo
    echo "OPTIONS:"
    echo "   --gogs-admin-user [username]       Gogs admin username to be created. Default 'gogs'"
    echo "   --gogs-admin-password [password]   Gogs admin password to be created. Default 'openshift3'"
    echo "   --gogs-user-count [num]            Number of users to be created on Gogs. Default 50"
    echo "   --openshift-password [password]    Password for existing OpenShift users. Default 'openshift3'"
    echo "   --apps-hostname-prefix [prefix]    Application hostname prefix in http://svc-namespace.prefix.hostname. Default 'apps'"
    echo "   --infra-project [project]          Project for workshop infra components e.g. Nexus and Gogs . Default 'ocp-workshop'"
    echo
}


################################
# OPTIONS                      #
################################

if [ "$(oc whoami)" != 'system:admin' ] ; then
  echo
  echo "Error: The workshop setup script must run as system:admin. Login as system:admin and re-run:"
  echo "$ oc login -u system:admin"
  echo 
  exit 255
fi

ARG_GOGS_ADMIN_USER=
ARG_GOGS_ADMIN_PWD=
ARG_OPENSHIFT_PWD=
ARG_APPS_HOSTNAME_PREFIX=
ARG_INFRA_PROJECT=
ARG_GOGS_USER_COUNT=
ARG_COMMAND=prepare

while :; do
    case $1 in
        prepare)
            ARG_COMMAND=prepare
            ;;
        cleanup)
            ARG_COMMAND=cleanup
            ;;
        --gogs-admin-user)
            if [ -n "$2" ]; then
                ARG_GOGS_ADMIN_USER=$2
                shift
            fi
            ;;
        --gogs-admin-password)
            if [ -n "$2" ]; then
                ARG_GOGS_ADMIN_PWD=$2
                shift
            fi
            ;;
        --openshift-password)
            if [ -n "$2" ]; then
                ARG_OPENSHIFT_PWD=$2
                shift
            fi
            ;;
        --apps-hostname-prefix)
            if [ -n "$2" ]; then
                ARG_APPS_HOSTNAME_PREFIX=$2
                shift
            fi
            ;;
        --infra-project)
            if [ -n "$2" ]; then
                ARG_INFRA_PROJECT=$2
                shift
            fi
            ;;
        --gogs-user-count)
            if [ -n "$2" ]; then
                ARG_GOGS_USER_COUNT=$2
                shift
            fi
            ;;
        --help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -?*)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
            shift
            ;;
        *) # Default case: If no more options then break out of the loop.
            break
    esac

    shift
done

################################
# CONFIG                       #
################################

GOGS_ADMIN_USER=${ARG_GOGS_ADMIN_USER:-gogs}
GOGS_ADMIN_PASSWORD=${ARG_GOGS_ADMIN_PWD:-openshift3}
USER_PASSWORD=${ARG_OPENSHIFT_PWD:-openshift3}
APPS_HOST_PREFIX=${ARG_APPS_HOSTNAME_PREFIX:-apps}
INFRA_PROJECT=${ARG_INFRA_PROJECT:-ocp-workshop}
GOGS_USER_COUNT=${ARG_GOGS_USER_COUNT:-50}

OPENSHIFT_MASTER=$(oc whoami --show-server)
OPENSHIFT_APPS_HOSTNAME=$APPS_HOST_PREFIX.$(oc whoami --show-server | sed "s|https://master\.\(.*\)|\1|g") 
GOGS_HOSTNAME=gogs-$INFRA_PROJECT.$OPENSHIFT_APPS_HOSTNAME
NEXUS_URL=http://nexus-$INFRA_PROJECT.$OPENSHIFT_APPS_HOSTNAME/content/groups/public/


################################
# FUNCTIONS                    #
################################

function wait_while_empty() {
  local _NAME=$1
  local _TIMEOUT=$(($2/5))
  local _CONDITION=$3

  echo "Waiting for $_NAME to be ready..."
  local x=1
  while [ -z "$(eval ${_CONDITION})" ]
  do
    echo "."
    sleep 5
    x=$(( $x + 1 ))
    if [ $x -gt $_TIMEOUT ]
    then
      echo "$_NAME still not ready, I GIVE UP!"
      exit 255
    fi
  done

  echo "$_NAME is ready."
}


function print_info() {
  echo
  echo "##############################################"
  echo "OpenShift master:      $OPENSHIFT_MASTER"
  echo "Gogs Admin User:       $GOGS_ADMIN_USER"
  echo "Gogs Admin Password:   $GOGS_ADMIN_PASSWORD"
  echo "Gogs Users:            user1..user$GOGS_USER_COUNT"
  echo "Gogs Password:         $USER_PASSWORD"
  echo "##############################################"
  echo
}


function create_infra_project() {
  oc get project $INFRA_PROJECT > /dev/null 2>&1

  if [ ! $? -eq 0 ]; then
    oc new-project $INFRA_PROJECT
    oc delete limits --all -n $INFRA_PROJECT
    oadm pod-network make-projects-global $INFRA_PROJECT > /dev/null 2>&1
  fi
}

# deploy Gogs
function deploy_gogs() {
oc process -f https://raw.githubusercontent.com/OpenShiftDemos/gogs-openshift-docker/rpm/openshift/gogs-persistent-template.yaml \
  --param=HOSTNAME=$GOGS_HOSTNAME \
  --param=GOGS_VERSION=0.11.4 \
  --param=DATABASE_USER=gogs \
  --param=DATABASE_PASSWORD=gogs \
  --param=DATABASE_NAME=gogs \
  --param=SKIP_TLS_VERIFY=true \
  -n $INFRA_PROJECT | oc create -f - -n $INFRA_PROJECT
}

function deploy_nexus() {
  oc process -f https://raw.githubusercontent.com/OpenShiftDemos/nexus/master/nexus2-persistent-template.yaml \
    -n $INFRA_PROJECT | oc create -f - -n $INFRA_PROJECT
  oc set resources dc/nexus --limits=cpu=1,memory=2Gi --requests=cpu=200m,memory=1Gi -n $INFRA_PROJECT
}

function deploy_guides() {
  oc new-app --name=guides \
    --docker-image=osevg/workshopper:ruby \
    --env=WORKSHOPS_URLS=https://raw.githubusercontent.com/openshift-roadshow/devops-workshop-guides/master/_devops-workshop.yml \
    --env=CONTENT_URL_PREFIX=https://raw.githubusercontent.com/openshift-roadshow/devops-workshop-guides/master \
    --env=OPENSHIFT_URL=$OPENSHIFT_MASTER \
    --env=OPENSHIFT_APPS_HOSTNAME=$OPENSHIFT_APPS_HOSTNAME \
    --env=OPENSHIFT_USER=userX \
    --env=OPENSHIFT_PASSWORD=$USER_PASSWORD \
    --env=GIT_SERVER_URL=http://$GOGS_HOSTNAME \
    --env=GIT_SERVER_INTERNAL_URL=http://$GOGS_HOSTNAME \
    --env=GIT_USER=userX \
    --env=GIT_PASSWORD=$USER_PASSWORD \
    --env=PROJECT_SUFFIX=X \
    -n $INFRA_PROJECT

  oc set probe dc/guides --readiness --liveness --get-url=http://:8080/ --failure-threshold=5 --initial-delay-seconds=15 -n $INFRA_PROJECT
  oc expose svc/guides -n $INFRA_PROJECT
}

function generate_gogs_users() {
  # wait till gogs is up
  wait_while_empty "Gogs PostgreSQL" 600 "oc get ep gogs-postgresql -o yaml -n $INFRA_PROJECT | grep '\- addresses:'"
  wait_while_empty "Gogs" 600 "oc get ep gogs -o yaml -n $INFRA_PROJECT | grep '\- addresses:'"

  # add gogs admin user
  curl -sD - -o /dev/null -L --post302 http://$GOGS_HOSTNAME/user/sign_up \
    --form user_name=$GOGS_ADMIN_USER \
    --form password=$GOGS_ADMIN_PASSWORD \
    --form retype=$GOGS_ADMIN_PASSWORD \
    --form email=$GOGS_ADMIN_USER@gogs.com

  sleep 1

  # create gogs users and repos

  # init cart-service repo
  local _REPO_DIR=/tmp/$(date +%s)-coolstore-microservice
  local _GITHUB_REPO_NAME=devops-workshop-labs
  rm -rf $_REPO_DIR
  mkdir $_REPO_DIR
  cd $_REPO_DIR
  curl -sL -o ./coolstore.zip https://github.com/openshift-roadshow/$_GITHUB_REPO_NAME/archive/master.zip
  unzip coolstore.zip
  cd $_GITHUB_REPO_NAME-master/cart-spring-boot
  git init
  git add . --all
  git config user.email "developer@rhdevops.com"
  git config user.name "developer"
  git commit -m "Initial add" && \
      
  local _GOGS_UID=1 # admin is uid 1
  for i in `seq 0 $GOGS_USER_COUNT`; do
    _GOGS_UID=$((_GOGS_UID+1))
    _GOGS_USER=user$i

    echo "Creating user $_GOGS_USER (uid=$_GOGS_UID)"
    curl -sD - -o /dev/null -L --post302 http://$GOGS_HOSTNAME/user/sign_up \
      --form user_name=$_GOGS_USER \
      --form password=$USER_PASSWORD \
      --form retype=$USER_PASSWORD \
      --form email=$_GOGS_USER@gogs.com

    # Create cart-service repository
    read -r -d '' _DATA_JSON << EOM
{
  "name": "cart-service",
  "private": false,
  "auto_init": true,
  "gitignores": "Java",
  "license": "Apache License 2.0",
  "readme": "Default"
}
EOM

    echo "Creating cart-service repo for user $_GOGS_USER (uid=$_GOGS_UID)"
    curl -sD - -o /dev/null -L -H "Content-Type: application/json" \
        -d "$_DATA_JSON" \
        -u $_GOGS_USER:$USER_PASSWORD \
        -X POST http://$GOGS_HOSTNAME/api/v1/user/repos

    # import cart-service github repo
    git remote add $_GOGS_USER http://$GOGS_HOSTNAME/$_GOGS_USER/cart-service.git
    git push -f http://$_GOGS_USER:$USER_PASSWORD@$GOGS_HOSTNAME/$_GOGS_USER/cart-service.git master

  done
  rm -rf $_REPO_DIR
}

function build_coolstore_images() {
  oc new-project coolstore-images

  # wait for nexus
  wait_while_empty "Nexus" 600 "oc get ep nexus -o yaml -n $INFRA_PROJECT | grep '\- addresses:'"

  # catalog service
  oc new-app redhat-openjdk18-openshift:1.1~https://github.com/openshift-roadshow/devops-workshop-labs.git \
        --context-dir=catalog-spring-boot \
        --name=catalog \
        --labels=app=coolstore \
        -n coolstore-images
  #         --build-env=MAVEN_MIRROR_URL=$NEXUS_URL \        
  oc cancel-build bc/catalog -n coolstore-images


  # gateway service
  oc new-app redhat-openjdk18-openshift:1.1~https://github.com/openshift-roadshow/devops-workshop-labs.git \
        --context-dir=gateway-vertx \
        --name=coolstore-gw \
        --labels=app=coolstore \
        -n coolstore-images
  oc cancel-build bc/coolstore-gw -n coolstore-images

  # inventory service
  oc new-app redhat-openjdk18-openshift:1.1~https://github.com/openshift-roadshow/devops-workshop-labs.git \
        --context-dir=inventory-wildfly-swarm \
        --name=inventory \
        --labels=app=coolstore \
        -n coolstore-images
  oc cancel-build bc/inventory -n coolstore-images

  # cart service
  oc new-app redhat-openjdk18-openshift:1.1~https://github.com/openshift-roadshow/devops-workshop-labs.git \
        --context-dir=cart-spring-boot \
        --name=cart \
        --labels=app=coolstore \
        -n coolstore-images
  oc cancel-build bc/cart -n coolstore-images

  # web ui
  oc new-app nodejs:4~https://github.com/openshift-roadshow/devops-workshop-labs.git \
        --context-dir=web-nodejs \
        --name=web-ui \
        --labels=app=coolstore \
        -n coolstore-images
  oc cancel-build bc/web-ui -n coolstore-images

  # we just need the buildconfigs
  oc delete dc,svc -l app=coolstore -n coolstore-images

  # build images
  oc start-build web-ui -n coolstore-images --follow
  oc start-build inventory -n coolstore-images --follow
  oc start-build catalog -n coolstore-images --follow
  oc start-build coolstore-gw -n coolstore-images --follow
  oc start-build cart -n coolstore-images --follow

  # tag in openshift namespace
  oc tag coolstore-images/web-ui:latest       openshift/coolstore-web-ui:prod
  oc tag coolstore-images/inventory:latest    openshift/coolstore-inventory:prod
  oc tag coolstore-images/catalog:latest      openshift/coolstore-catalog:prod
  oc tag coolstore-images/coolstore-gw:latest openshift/coolstore-gateway:prod
  oc tag coolstore-images/cart:latest         openshift/coolstore-cart:prod

  # add coolstore template
  oc create -f https://raw.githubusercontent.com/openshift-roadshow/devops-workshop-labs/master/openshift/coolstore-deployment-template.yaml -n openshift
}

function clean_up() {
  local _PROJECTS="$INFRA_PROJECT lab-infra coolstore-images"
  # delete projects
  for i in `seq 0 $GOGS_USER_COUNT`; do
    _PROJECTS+=" explore-$i dev-$i prod-$i"
  done

  echo "Deleting projects: $_PROJECTS"
  oc delete project $_PROJECTS > /dev/null 2>&1

  echo "Adjusting limits..."
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

  oc delete template coolstore -n openshift
}

################################
# MAIN                         #
################################


case "$ARG_COMMAND" in
    prepare)
        pushd ~ >/dev/null 
        print_info; sleep 1
        create_infra_project; sleep 1
        deploy_gogs; sleep 1 
        deploy_nexus; sleep 1
        deploy_guides; sleep 1
        generate_gogs_users; sleep 1
        build_coolstore_images;
        popd >/dev/null
        
        echo
        echo "Prepare completed successfully!"
        ;;
    cleanup)
        clean_up

        echo
        echo "Clean up completed successfully!"
        ;;
    *)
        echo "Invalid command specified: '$ARG_COMMAND'"
        usage
        ;;
esac



