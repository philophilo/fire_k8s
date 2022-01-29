init:
	@echo initializing terraform
	@cd terraform && \
		terraform init \
		-backend-config="bucket=${BUCKET}" \
		-backend-config="key=${KEY}" \
		-backend-config="region=${REGION}"

plan: init
	@echo Running Terraform plan
	@cd terraform && \
		terraform plan

apply: init
	@echo Applying terraform plan
	@cd terraform && \
		terraform apply -auto-approve

deploy: apply
	@echo deploying ingress and application
	@cd k8s && \
		/bin/bash script.sh create

destroy:
	@echo destroying infrastructure
	@cd k8s && \
		/bin/bash script.sh delete
	@cd terraform && \
		terraform destroy -auto-approve

fmt:
	@echo Format Terraform scripts
	@cd terraform && \
		terraform fmt

# docker-compose

local:
	@echo Setting up local environment
	@docker-compose up -d
	@docker-compose exec infra /bin/bash

down:
	@echo Stopping the local environment
	@docker-compose down
