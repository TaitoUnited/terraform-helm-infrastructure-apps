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
  count   = (
    var.generate_ingress_nginx_dhparam == true
    ? length(local.ingressNginxControllers)
    : 0
  )
  program = [ "${path.module}/dhparam.sh", "${count.index}", "${path.module}" ]
}

resource "helm_release" "nginx_extras" {
  count      = length(local.ingressNginxControllers)

  name       = "${local.ingressNginxControllers[count.index].name}-extras"
  namespace  = local.ingressNginxControllers[count.index].name
  chart      = "${path.module}/nginx-extras"
  create_namespace = true

  set_sensitive {
    name     = "dhparam"
    type     = "string"
    value    = (
      var.generate_ingress_nginx_dhparam == true
      ? data.external.dhparam[count.index].result.key
      : null
    )
  }
}

resource "helm_release" "ingress_nginx" {
  depends_on = [helm_release.nginx_extras]
  count      = length(local.ingressNginxControllers)

  name       = local.ingressNginxControllers[count.index].name
  namespace  = local.ingressNginxControllers[count.index].name
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.ingress_nginx_version
  wait       = false

  values = [
    file("${path.module}/helm-ingress.yaml"),
    jsonencode({
      controller = {
        config = local.ingressNginxConfigMaps[count.index]
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
    value    = local.ingressNginxControllers[count.index].class
  }

  set {
    name     = "controller.replicaCount"
    value    = local.ingressNginxControllers[count.index].replicas
  }

  set {
    name     = "controller.maxmindLicenseKey"
    value    = local.ingressNginxControllers[count.index].maxmindLicenseKey
  }

  set {
    name     = "controller.service.loadBalancerIP"
    type     = "string"
    value    = length(var.ingressNginxLoadBalancerIPs) > 0 ? var.ingressNginxLoadBalancerIPs[count.index] : ""
  }

  set {
    name     = "controller.service.externalTrafficPolicy"
    value    = "Local"
  }

  set {
    name     = "controller.metrics.enabled"
    type     = "string"
    value    = local.ingressNginxControllers[count.index].metricsEnabled
  }

  set {
    name     = "controller.config.log-format-escape-json"
    type     = "string"
    value    = "true"
  }

  dynamic "set" {
    for_each = var.generate_ingress_nginx_dhparam == true ? [ 1 ] : []
    content {
      name     = "controller.config.ssl-dh-param"
      type     = "string"
      value    = "${local.ingressNginxControllers[count.index].name}/lb-dhparam"
    }
  }

  dynamic "set" {
    for_each = local.ingressNginxControllers[count.index].tcpServices != null ? local.ingressNginxControllers[count.index].tcpServices : {}
    content {
      name   = "tcp.${set.key}"
      value  = set.value
    }
  }

  dynamic "set" {
    for_each = local.ingressNginxControllers[count.index].udpServices != null ? local.ingressNginxControllers[count.index].udpServices : {}
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
