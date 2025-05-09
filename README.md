# Helm infrastructure apps for Kubernetes

Provides some useful infrastructure applications for Kubernetes:

- [NGINX ingress](https://kubernetes.github.io/ingress-nginx/)
- [cert-manager](https://cert-manager.io/)

This module is used by the following modules:

- [Kubernetes for AWS](https://registry.terraform.io/modules/TaitoUnited/kubernetes/aws)
- [Kubernetes for Azure](https://registry.terraform.io/modules/TaitoUnited/kubernetes/azurerm)
- [Kubernetes for Google](https://registry.terraform.io/modules/TaitoUnited/kubernetes/google)
- [Kubernetes for DigitalOcean](https://registry.terraform.io/modules/TaitoUnited/kubernetes/digitalocean)

Example usage:

```
module "helm_apps" {
  source                      = "TaitoUnited/infrastructure-apps/helm"
  version                     = "2.9.1"

  ingressNginxLoadBalancerIPsByName = {
    nginx1 = "123.123.123.1"
    nginx2 = "123.123.123.2"
    nginx3 = "123.123.123.3"
  }

  generate_ingress_dhparam    = false
  email                       = "devops@mydomain.com"

  resources                   = yamldecode(file("${path.root}/../my-kube.yaml"))
}
```

Example YAML for resources:

```
# Certificate managers
certManager:
  enabled: false

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
```

Contributions are welcome!
