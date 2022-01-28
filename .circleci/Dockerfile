FROM python:3.9-slim

RUN apt-get update && apt-get install -y apt-transport-https \
    ca-certificates \
    build-essential \
    libpq-dev \
    python3-dev \
    curl \
    postgresql \
    postgresql-contrib \
	git \
    gettext \
    gnupg \
    wget \
    unzip \
    jq

RUN curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

RUN echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

RUN apt-get update && \
    apt-get install -y kubectl

RUN pip install awscli

RUN wget https://releases.hashicorp.com/terraform/1.1.0/terraform_1.1.0_linux_amd64.zip && \
        unzip terraform_1.1.0_linux_amd64.zip && \
        mv terraform /usr/bin/terraform

WORKDIR /app
