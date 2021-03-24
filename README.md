# Helm infrastructure apps for Kubernetes

Provides some useful infrastructure applications for Kubernetes: [NGINX ingress](https://kubernetes.github.io/ingress-nginx/), [cert-manager](https://cert-manager.io/), [Falco](https://falco.org/), [Jaeger](https://www.jaegertracing.io/), [Sentry](https://sentry.io), [Jenkins X](https://jenkins-x.io/), [Istio](https://istio.io/), and [Knative](https://knative.dev/).

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

  generate_ingress_dhparam    = false
  pod_security_policy_enabled = true
  ingressNginxLoadBalancerIPs = [
    "123.123.123.1", "123.123.123.2", "123.123.123.3"
  ]
  email                       = "devops@mydomain.com"

  resources                   = yamldecode(file("${path.root}/../my-kube.yaml"))
}
```

Example YAML for resources:

```
# Ingress controllers
ingressNginxControllers:
  - name: ingress-nginx
    class: nginx
    replicas: 3
    metricsEnabled: true
    # MaxMind license key for GeoIP2: https://support.maxmind.com/account-faq/license-keys/how-do-i-generate-a-license-key/
    maxmindLicenseKey:
    # Map TCP/UDP connections to services
    tcpServices:
      3000: my-namespace/my-tcp-service:9000
    udpServices:
      3001: my-namespace/my-udp-service:9001
    # See https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/
    configMap:
      # Hardening
      # See https://kubernetes.github.io/ingress-nginx/deploy/hardening-guide/
      keep-alive: 10
      custom-http-errors: 403,404,503,500
      server-snippet: >
        location ~ /\.(?!well-known).* {
          deny all;
          access_log off;
          log_not_found off;
          return 404;
        }
      hide-headers: Server,X-Powered-By
      ssl-ciphers: EECDH+AESGCM:EDH+AESGCM
      enable-ocsp: true
      hsts-preload: true
      ssl-session-tickets: false
      client-header-timeout: 10
      client-body-timeout: 10
      large-client-header-buffers: 2 1k
      client-body-buffer-size: 1k
      proxy-body-size: 1k
      # Firewall and access control
      enable-modsecurity: true
      enable-owasp-modsecurity-crs: true
      use-geoip: false
      use-geoip2: true
      enable-real-ip: false
      whitelist-source-range:
      block-cidrs:
      block-user-agents:
      block-referers:

# Certificate managers
certManager:
  enabled: false
```

Contributions are welcome!
