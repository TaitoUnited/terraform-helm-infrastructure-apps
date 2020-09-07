# Helm infrastructure apps for Kubernetes

Provides some useful infrastructure applications for Kubernetes: [NGINX ingress](https://kubernetes.github.io/ingress-nginx/), [cert-manager](https://cert-manager.io/), [Falco](https://falco.org/), [Jaeger](https://www.jaegertracing.io/), [Sentry](https://sentry.io), [Jenkins X](https://jenkins-x.io/), [Istio](https://istio.io/), [Knative](https://knative.dev/), and [Kafka](https://kafka.apache.org/)

NOTE: Currently only NGINX ingress and cert-manager has been implemented.

This module is used by the following modules:

- [Kubernetes infrastructure for AWS](https://registry.terraform.io/modules/TaitoUnited/kubernetes-infrastructure/aws)
- [Kubernetes infrastructure for Azure](https://registry.terraform.io/modules/TaitoUnited/kubernetes-infrastructure/azurerm)
- [Kubernetes infrastructure for Google](https://registry.terraform.io/modules/TaitoUnited/kubernetes-infrastructure/google)
- [Kubernetes infrastructure for DigitalOcean](https://registry.terraform.io/modules/TaitoUnited/kubernetes-infrastructure/digitalocean)

Example usage:

```
module "helm_apps" {
  source                      = "TaitoUnited/infrastructure-apps/helm"
  version                     = "1.0.0"

  pod_security_policy_enabled = true
  nginxIngressLoadBalancerIPs = [ "123.123.123.1", "123.123.123.2", "123.123.123.3" ]
  email                       = "devops@mydomain.com"

  resources                   = yamldecode(file("${path.root}/../my-kube.yaml"))
}
```

Example YAML for resources:

```
# Ingress controllers
nginxIngressControllers:
  - class: nginx
    replicas: 3
    metricsEnabled: true
    maxmindLicenseKey: # For GeoIP
    # See https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/
    configMap:
      enable-modsecurity: true
      enable-owasp-modsecurity-crs: true
      use-geoip: false
      use-geoip2: true
      enable-real-ip: false
      enable-opentracing: false
      whitelist-source-range:
      # Block malicious IPs. See https://www.projecthoneypot.org/list_of_ips.php
      block-cidrs:
      block-user-agents:
      block-referers:
    # Map TCP/UDP connections to services
    tcpServices:
      3000: my-namespace/my-tcp-service:9000
    udpServices:
      3001: my-namespace/my-udp-service:9001

# Certificate managers
certManager:
  enabled: false

# Platforms
istio:
  enabled: false
knative:
  enabled: false

# Logging, monitoring, and tracing
falco:
  enabled: false # NOTE: Not supported yet
jaeger:
  enabled: false # NOTE: Not supported yet
sentry:
  enabled: false # NOTE: Not supported yet

# CI/CD
jenkinsx:
  enabled: false # NOTE: Not supported yet

# Event handling
kafka:
  enabled: false # NOTE: Not supported yet
```

Contributions are welcome!
