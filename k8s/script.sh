#! /bin/bash

: '
The script manages the configuration of Kubernetes Manifests
It used when `make deploy` is run. In this scenario is creates
and updates resources in the cluster.
When `make delete` is run, it deletes all the resources in the
cluster
'

# configre aws cli
if [[ $ENV == "dev" ]]; then
    mkdir -p ~/.aws
    echo "[default]" > ~/.aws/credentials
    echo "aws_access_key_id = ${AWS_ACCESS_KEY}" >> ~/.aws/credentials
    echo "aws_secret_access_key = ${AWS_SECRET_KEY}" >> ~/.aws/credentials
    echo "[default]" > ~/.aws/config
    echo "region =${REGION}" >> ~/.aws/config
fi

# update kubectl context
aws eks update-kubeconfig --name fire-cluster

# configure nginx controller
function create_nginx_ingress {
    kubectl apply -f ingress/namespace.yaml
    kubectl apply -f ingress/service-account.yaml
    envsubst < ingress/default-server-secret.yaml | kubectl apply -f -
    kubectl apply -f ingress/nginx-config.yaml
    kubectl apply -f ingress/rbac.yaml
    kubectl apply -f ingress/ingress-class.yaml
    kubectl apply -f ingress/nginx-ingress-deployment.yaml
    kubectl apply -f ingress/loadbalancer-aws-elb.yaml
}

# Deploy application
function deploy_app {
    envsubst < app/namespace.yaml | kubectl apply -f -
    envsubst < app/database-configmap.yaml | kubectl apply -f -
    envsubst < app/database-deployment.yaml | kubectl apply -f -
    envsubst < app/database-service.yaml | kubectl apply -f -

    until [ ! -z $(kubectl get statefulset -n $NAMESPACE | grep db | awk '{print $2}' | grep 1/1) ]; do
        if [ $? -eq 1 ]; then
            echo 'Waiting for Database setup...'
            sleep 5
        fi
    done; echo "Database is ready!"

    envsubst < app/backend-configmap.yaml | kubectl apply -f -
    envsubst < app/backend-deployment.yaml | kubectl apply -f -
    envsubst < app/backend-service.yaml | kubectl apply -f -
}

# Delete application configuration in kubernetes cluster
function delete_app {
    envsubst < app/database-service.yaml | kubectl delete -f -
    envsubst < app/database-deployment.yaml | kubectl delete -f -
    envsubst < app/database-configmap.yaml | kubectl delete -f -
    envsubst < app/backend-configmap.yaml | kubectl delete -f -
    envsubst < app/backend-deployment.yaml | kubectl delete -f -
    envsubst < app/backend-service.yaml | kubectl delete -f -
}

# Delete nginx-controller configuration
function delete_nginx_ingress {
    kubectl delete -f ingress/loadbalancer-aws-elb.yaml
    kubectl delete -f ingress/nginx-ingress-deployment.yaml
    kubectl delete -f ingress/ingress-class.yaml
    kubectl delete -f ingress/rbac.yaml
    kubectl delete -f ingress/nginx-config.yaml
    kubectl delete -f ingress/default-server-secret.yaml
    kubectl delete -f ingress/service-account.yaml
    kubectl delete -f ingress/namespace.yaml
}

# configure Ingress for the application
function config_ingress {
    envsubst < ingress/ingress.yaml | kubectl apply -f -
}

# Check if Domain provided exists in route53 hosted zone
function get_rout53_dns {
    # accepts either create or delete as an argument
    export HOSTED_ZONE_ID=$(aws route53 list-hosted-zones | jq '.HostedZones| .[0] | .Id' | sed 's:.*/::' | tr -d '"')
    DNS_RECORD=$(aws route53 list-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --query "ResourceRecordSets[?Name == '$DOMAIN.']")
    dns_state=false

    if [[ $DNS_RECORD == "[]" ]]; then
        dns_state=false
    else
        dns_state=true
    fi

    if [[ $1 == "create" ]]; then
        if [[ $dns_state == "false" ]]; then
            create_route53_record
        else
            echo "DNS record exists!"
        fi
    elif [[ $1 == "delete" ]]; then
        if [[ $dns_state != "false" ]]; then
            delete_route53_record
        else
            echo "DNS record doesn't exist!"
        fi
    fi

}

# If record does not exist create it
function create_route53_record {
    envsubst < create-domain.json > create-domain-out.json
    aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --change-batch file://create-domain-out.json
}

# If record exists delete it (when make delete is run)
function delete_route53_record {
    envsubst < delete-domain.json > delete-domain-out.json
    aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --change-batch file://delete-domain-out.json
}

# Get the DNS of the loadbalancer where the ingress is accessed
function get_lb_dns {
    export DNS="$(kubectl get svc --namespace=nginx-ingress | grep nginx-ingress | awk '{print $4}')"
}

if [[ $1 == "create" ]]; then
    create_nginx_ingress
    deploy_app
    config_ingress
    get_lb_dns
    get_rout53_dns $1
elif [[ $1 == "delete" ]]; then
    get_lb_dns
    delete_app
    delete_nginx_ingress
    get_rout53_dns $1
fi
