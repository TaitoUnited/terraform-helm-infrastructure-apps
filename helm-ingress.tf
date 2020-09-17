/**
 * Copyright 2020 Taito United
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

data "external" "dhparam" {
  count   = length(local.nginxIngressControllers)
  program = [
    "sh",
    "-c",
    "jq -n --arg key \"$(openssl dhparam 4096 2> /dev/null | base64)\""
  ]
}

resource "helm_release" "nginx_extras" {
  count      = length(local.nginxIngressControllers)

  name       = local.nginxIngressControllers[count.index].name
  namespace  = local.nginxIngressControllers[count.index].name
  chart      = "${path.module}/nginx-extras"

  set {
    name     = "dhparam"
    type     = "string"
    value    = data.external.dhparam[count.index].result.key
  }
}

resource "helm_release" "nginx_ingress" {
  depends_on = [helm_release.nginx_extras]
  count      = length(local.nginxIngressControllers)

  name       = local.nginxIngressControllers[count.index].name
  namespace  = local.nginxIngressControllers[count.index].name
  repository = "https://kubernetes-charts.storage.googleapis.com/"
  chart      = "nginx-ingress"
  version    = var.nginx_ingress_version
  wait       = false

  set {
    name     = "podSecurityPolicy.enabled"
    value    = var.pod_security_policy_enabled
  }

  set {
    name     = "rbac.create"
    value    = "true"
  }

  set {
    name     = "serviceAccount.create"
    value    = "true"
  }

  set {
    name     = "controller.ingressClass"
    value    = local.nginxIngressControllers[count.index].class
  }

  set {
    name     = "controller.replicaCount"
    value    = local.nginxIngressControllers[count.index].replicas
  }

  set {
    name     = "controller.maxmindLicenseKey"
    value    = local.nginxIngressControllers[count.index].maxmindLicenseKey
  }

  set {
    name     = "controller.service.loadBalancerIP"
    type     = "string"
    value    = length(var.nginxIngressLoadBalancerIPs) > 0 ? var.nginxIngressLoadBalancerIPs[count.index] : ""
  }

  set {
    name     = "controller.service.externalTrafficPolicy"
    value    = "Local"
  }

  set {
    name     = "controller.metrics.enabled"
    type     = "string"
    value    = local.nginxIngressControllers[count.index].metricsEnabled
  }

  set {
    name     = "controller.config.ssl-dh-param"
    type     = "string"
    value    = "${local.nginxIngressControllers[count.index].name}/lb-dhparam"
  }

  set {
    name     = "controller.config.log-format-escape-json"
    type     = "string"
    value    = "true"
  }

  set {
    name     = "controller.config.log-format-upstream"
    type     = "string"
    value    = "{\"timestamp\": \"$time_iso8601\", \"requestId\": \"$req_id\", \"proxyUpstreamName\": \"$proxy_upstream_name\", \"proxyAlternativeUpstreamName\": \"$proxy_alternative_upstream_name\", \"upstreamStatus\": \"$upstream_status\", \"upstreamAddr\": \"$upstream_addr\", \"httpRequest\":{ \"requestMethod\": \"$request_method\", \"requestUrl\": \"$host$request_uri\", \"status\": $status, \"requestSize\": \"$request_length\", \"responseSize\": \"$upstream_response_length\", \"userAgent\": \"$http_user_agent\", \"remoteIp\": \"$remote_addr\", \"referer\": \"$http_referer\", \"responseTimeS\": \"$upstream_response_time\", \"protocol\":\"$server_protocol\"}}"
  }

  dynamic "set" {
    for_each = local.nginxIngressControllers[count.index].configMap
    content {
      name   = "controller.config." + set.key
      type   = "string"
      value  = set.value
    }
  }

  dynamic "set" {
    for_each = local.nginxIngressControllers[count.index].tcpServices
    content {
      name   = "tcp." + set.key
      value  = set.value
    }
  }

  dynamic "set" {
    for_each = local.nginxIngressControllers[count.index].udpServices
    content {
      name   = "udp." + set.key
      value  = set.value
    }
  }
}

resource "helm_release" "cert_manager_crd" {
  depends_on = [helm_release.nginx_ingress]

  count      = local.certManager.enabled ? 1 : 0

  name       = "cert-manager-crd"
  namespace  = "cert-manager-crd"
  chart      = "${path.module}/cert-manager-crd"
}

resource "null_resource" "cert_manager_crd_wait" {
  depends_on = [helm_release.cert_manager_crd]

  triggers = {
    cert_manager_enabled = local.certManager.enabled
    cert_manager_version = var.cert_manager_version
  }

  provisioner "local-exec" {
    command = "sleep 30"
  }
}

resource "helm_release" "cert_manager" {
  depends_on = [null_resource.cert_manager_crd_wait]

  count      = local.certManager.enabled ? 1 : 0

  name       = "cert-manager"
  namespace  = "cert-manager"
  repository = "https://charts.jetstack.io/"
  chart      = "cert-manager"
  version    = var.cert_manager_version

  set {
    name     = "global.rbac.create"
    value    = "true"
  }

  set {
    name     = "global.podSecurityPolicy.enabled"
    value    = var.pod_security_policy_enabled
  }

  set {
    name     = "securityContext.enabled"
    value    = "true"
  }

  set {
    name     = "serviceAccount.create"
    value    = "true"
  }
}

resource "helm_release" "letsencrypt_issuer" {
  depends_on = [helm_release.cert_manager]

  count      = local.certManager.enabled ? 1 : 0

  name       = "letsencrypt-issuer"
  namespace  = "cert-manager"
  chart      = "${path.module}/letsencrypt-issuer"

  set {
    name     = "email"
    value    = var.email
  }
}
