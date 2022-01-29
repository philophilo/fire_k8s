[![CircleCI](https://circleci.com/gh/philophilo/fire_k8s.svg?style=shield)](https://app.circleci.com/pipelines/github/philophilo/fire_k8s?filter=all)

# Introduction

The repository holds infrastructure code for [fire_app](https://github.com/philophilo/fire_k8s.git). The network and cluster are created using Terraform. The Kubernetes resources for ingress and application are created by `kubectl` from a bash script `k8s/srcript.sh`.


### Requirements
```
- GNU Make
- Docker
- Docker-compose
```

### Setup
Clone the repository and create `.env` file in the docker directory and add the following creadentials

```
git clone https://github.com/philophilo/fire_k8s.git
```
Required credentials

The environments below are required for AWS, Terraform, and Kubernetes manifests.

```
AWS_SECRET_KEY=
AWS_ACCESS_KEY=
REGION=
KEY=
BUCKET=
BACKEND_IMAGE="philophilo/test"
DATABASE_USER=
DATABASE_PASSWORD=
DATABASE_NAME=
DATABASE_HOST=
DATABASE_PORT=5432
SECRET_KEY=
EMAIL_HOST='smtp.gmail.com'
EMAIL_PORT=587
EMAIL_HOST_USER=
EMAIL_HOST_PASSWORD=
NAMESPACE=default
PGDATA='/data/pgdata'
TLS_CRT=
TLS_KEY=
DOMAIN=sample.example.com
ENV=dev
```
#### Notes on environment variables
- [How to setup Gmail SMTP server](https://kinsta.com/blog/gmail-smtp-server/)

- Use `philophilo/test` for testing purposes in a local environment

- The default [secrets](https://github.com/nginxinc/kubernetes-ingress/blob/master/deployments/common/default-server-secret.yaml) (`TLS_CRT` and `TLS_KEY`) in the kubernetes repository can also work. These are required in `k8s/ingress/default-server-secret.yaml`.

- The `ENV=dev` environment variable is used for the local environment to configure AWS in the container. Otherwise in circleci it will be installed in the root user's home directory.

- The `DOMAIN` variable will be used to access the application (such as `http://sample.example.com`). It will be added to Route53 as a CNAME record.

### Quick local setup
When the credentials have been setup, run `make local`. This will setup the docker container and ready for use.
`make down` will stop and remove the container that was created earlier.
Run `make deploy` to create the Terraform infrastructure and create kubenetes resources in the cluster.
The rest of the make commands can be used inside the container.

### The necessary Make commands

`make init` Initializes Terraform, downloading modules and providers

`make plan` Prints out the Terraform plan to be applied

`make apply` Runs Terraform plan and applies the plan to AWS

`make deploy` Runs Terraform apply and runs `k8s/script.sh` to implement Kubernetes configurations in the manifests in `k8s/ingress/` and `k8s/app`. `k8s/ingress/` contains manifests for the ingress while ``k8s/app/` contains manifests for the [api](https://github.com/philophilo/fire_app).

`make destroy` Destroys the Terraform infrastructure and all resources created by the Kubernetes manifests.

`make fmt` Lints the terraform scripts in `terraform`

`make local` Creates a local development environment in a Docker container with Docker-compose

`make down` Stops and removes the container used for local development

### Continuous Integration (CI)
A push to master or merge into master will trigger `terraform plan` on Circleci and `terraform apply -auto-approve`. Otherwise any other branches will run `terraform plan`. These are run using `make deploy` as seen in the [Circlci configuration](https://github.com/philophilo/fire_k8s/blob/master/.circleci/config.yml#L71).

The deployment can also be triggered from [fire_app](https://github.com/philophilo/fire_app) on a push to master or merge to master. fire_app [deletes](https://github.com/philophilo/fire_app/blob/master/.circleci/config.yml#L52) the existing `BACKEND_IMAGE` environment variable in the project and creates [a new one](https://github.com/philophilo/fire_app/blob/master/.circleci/config.yml#L53) with the updated tag through the Circleci api. Deployments from this repository will therefore have the lastest tag or version of the image for deployment. The variable appears in `k8s/app/backend-deployment.yaml`.

### Accessing the cluster
Kubectl commands are available after `make deploy`

### Accessing the application
After a few minutes, when changes have been propagated, the application can be accessed through `DOMAIN` variable in a browser.