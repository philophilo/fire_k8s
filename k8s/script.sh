#! /bin/bash

if [[ $ENV != "testing" ]]; then
    export $(cat .env | xargs)
fi

aws eks update-kubeconfig --name fire-cluster

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

function delete_app {
    envsubst < app/database-service.yaml | kubectl delete -f -
    envsubst < app/database-deployment.yaml | kubectl delete -f -
    envsubst < app/database-configmap.yaml | kubectl delete -f -
    envsubst < app/backend-configmap.yaml | kubectl delete -f -
    envsubst < app/backend-deployment.yaml | kubectl delete -f -
    envsubst < app/backend-service.yaml | kubectl delete -f -
}

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

function config_ingress {
    envsubst < ingress/ingress.yaml | kubectl apply -f -
}

function get_rout53_dns {
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
            create_lb_dns
        else
            echo "DNS record exists!"
        fi
    elif [[ $1 == "delete" ]]; then
        if [[ $dns_state != "false" ]]; then
            delete_lb_dns
        else
            echo "DNS record doesn't exist!"
        fi
    fi

}

function create_lb_dns {
    envsubst < create-domain.json > create-domain-out.json
    aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --change-batch file://create-domain-out.json
}

function delete_lb_dns {
    envsubst < delete-domain.json > delete-domain-out.json
    aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --change-batch file://delete-domain-out.json
}

function get_lb_dns {
    export DNS="$(kubectl get svc --namespace=nginx-ingress | grep nginx-ingress | awk '{print $4}')"
}

if [[ $1 == "create" ]]; then
    create_nginx_ingress
    deploy_app
    config_ingress
    get_lb_dns
    get_rout53_dns create
elif [[ $1 == "delete" ]]; then
    get_lb_dns
    delete_app
    delete_nginx_ingress
    get_rout53_dns delete
fi
