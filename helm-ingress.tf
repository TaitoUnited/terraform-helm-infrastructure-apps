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
  for_each = {for item in (var.generate_ingress_dhparam == true ? local.ingressNginxControllers : []): item.name => item}
  program = [ "${path.module}/dhparam.sh", each.key, path.module ]
}

resource "helm_release" "nginx_extras" {
  for_each   = {for item in local.ingressNginxControllers: item.name => item}

  name       = "${each.value.name}-extras"
  namespace  = each.value.name
  chart      = "${path.module}/nginx-extras"
  create_namespace = true

  dynamic "set_sensitive" {
    for_each = var.generate_ingress_dhparam == true ? [ 1 ] : []
    content {
      name     = "dhparam"
      type     = "string"
      value    = data.external.dhparam[each.key].result.key
    }
  }
}

resource "helm_release" "ingress_nginx" {
  depends_on = [helm_release.nginx_extras]
  for_each   = {for item in local.ingressNginxControllers: item.name => item}

  name       = each.value.name
  namespace  = each.value.name
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.ingress_nginx_version
  wait       = false

  values = [
    file("${path.module}/helm-ingress.yaml"),
    jsonencode({
      controller = {
        config = local.ingressNginxConfigMaps[each.key]
      }
    })
  ]

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
    value    = each.value.class
  }

  set {
    name     = "controller.replicaCount"
    value    = each.value.replicas
  }

  set {
    name     = "controller.maxmindLicenseKey"
    value    = each.value.maxmindLicenseKey
  }

  set {
    name     = "controller.service.loadBalancerIP"
    type     = "string"
    value    = length(var.ingressNginxLoadBalancerIPs) > 0 ? var.ingressNginxLoadBalancerIPs[each.key] : ""
  }

  set {
    name     = "controller.service.externalTrafficPolicy"
    value    = "Local"
  }

  set {
    name     = "controller.metrics.enabled"
    type     = "string"
    value    = each.value.metricsEnabled
  }

  set {
    name     = "controller.config.log-format-escape-json"
    type     = "string"
    value    = "true"
  }

  dynamic "set" {
    for_each = var.generate_ingress_dhparam == true ? [ 1 ] : []
    content {
      name     = "controller.config.ssl-dh-param"
      type     = "string"
      value    = "${each.value.name}/lb-dhparam"
    }
  }

  dynamic "set" {
    for_each = each.value.tcpServices != null ? each.value.tcpServices : {}
    content {
      name   = "tcp.${set.key}"
      value  = set.value
    }
  }

  dynamic "set" {
    for_each = each.value.udpServices != null ? each.value.udpServices : {}
    content {
      name   = "udp.${set.key}"
      value  = set.value
    }
  }
}

resource "helm_release" "cert_manager_crd" {
  depends_on = [helm_release.ingress_nginx]

  count      = local.certManager.enabled ? 1 : 0

  name       = "cert-manager-crd"
  namespace  = "cert-manager"
  chart      = "${path.module}/cert-manager-crd"
  create_namespace = true
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
