FROM cr.yandex/crp2cvbrp76d7dmfegco/docker.io/library/python:3.12.1-alpine

ENV KUSTOMIZE_URL=https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh
ENV FLUXCD_URL=https://fluxcd.io/install.sh
ENV HELM_URL=https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
ENV DYFF_URL=https://git.io/JYfAY
ENV KUBECONFORM_URL=https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-amd64.tar.gz
ENV VERIFY_CHECKSUM=false

# Настройки flux-local
ENV FLUX_LOCAL_TIMEOUT=120
ENV FLUX_LOCAL_HELM_CACHE_DIR=/cache/flux-local/helm

RUN apk add --no-cache \
    bash \
    curl \
    git \
    jq \
    yq

RUN curl -s ${KUSTOMIZE_URL}  | bash && \
    curl -s ${FLUXCD_URL}| bash && \
    curl ${HELM_URL} | bash && \
    curl -s --location ${DYFF_URL} | bash && \
    curl -L ${KUBECONFORM_URL} --output kubeconform.tar.gz && \
    tar xvzf kubeconform.tar.gz && \
    mv kustomize kubeconform /usr/local/bin/ && \
    mkdir -p ${FLUX_LOCAL_HELM_CACHE_DIR}

COPY . /tmp/flux-local

RUN pip install --no-cache-dir uv && \
    uv pip install --system /tmp/flux-local && \
    rm -rf /tmp/flux-local
