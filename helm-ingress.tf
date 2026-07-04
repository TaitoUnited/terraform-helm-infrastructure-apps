/**
 * Copyright 2021 Taito United
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

  set_sensitive = concat(
    [],
    var.generate_ingress_dhparam ? [
      {
        name  = "dhparam"
        type  = "string"
        value = data.external.dhparam[each.key].result.key
      }
    ] : []
  )
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
        config = local.ingressNginxConfigMaps[each.value.name]
      }
    })
  ]

  set = concat(
    [
      {
        name  = "rbac.create"
        value = "true"
      },
      {
        name  = "serviceAccount.create"
        value = "true"
      },
      {
        /* TODO: make configurable and false by default */
        name  = "controller.allowSnippetAnnotations"
        value = "true"
      },
      {
        /* TODO: make configurable and Medium by default */
        name  = "controller.config.annotations-risk-level"
        type  = "string"
        value = "Critical"
      },
      {
        name  = "controller.ingressClass"
        value = each.value.class
      },
      {
        name  = "controller.replicaCount"
        value = each.value.replicas
      },
      {
        name  = "controller.maxmindLicenseKey"
        value = each.value.maxmindLicenseKey != null ? each.value.maxmindLicenseKey : ""
      },
      {
        name  = "controller.service.loadBalancerIP"
        type  = "string"
        value = length(values(var.ingressNginxLoadBalancerIPsByName)) > 0 ? var.ingressNginxLoadBalancerIPsByName[each.key] : ""
      },
      {
        name  = "controller.service.externalTrafficPolicy"
        value = "Local"
      },
      {
        name  = "controller.metrics.enabled"
        type  = "string"
        value = each.value.metricsEnabled != null ? each.value.metricsEnabled : false
      },
      {
        name  = "controller.config.log-format-escape-json"
        type  = "string"
        value = "true"
      },
    ],

    var.generate_ingress_dhparam ? [
      {
        name  = "controller.config.ssl-dh-param"
        type  = "string"
        value = "${each.value.name}/lb-dhparam"
      }
    ] : [],

    [
      for port, service in coalesce(each.value.tcpServices, {}) : {
        name  = "tcp.${port}"
        value = service
      }
    ],

    [
      for port, service in coalesce(each.value.udpServices, {}) : {
        name  = "udp.${port}"
        value = service
      }
    ]
  )
}

resource "helm_release" "cert_manager" {
  depends_on = [helm_release.ingress_nginx]

  count      = local.certManager.enabled ? 1 : 0

  name       = "cert-manager"
  namespace  = "cert-manager"
  repository = "https://charts.jetstack.io/"
  chart      = "cert-manager"
  version    = var.cert_manager_version
  create_namespace = true

  set = [
    {
      name     = "global.rbac.create"
      value    = "true"
    },
    {
      name     = "securityContext.enabled"
      value    = "true"
    },
    {
      name     = "serviceAccount.create"
      value    = "true"
    },
    {
      name     = "installCRDs"
      value    = "true"
    }
  ]
}

resource "helm_release" "letsencrypt_issuer" {
  depends_on = [helm_release.cert_manager]

  count      = local.certManager.enabled ? 1 : 0

  name       = "letsencrypt-issuer"
  namespace  = "letsencrypt-issuer"
  chart      = "${path.module}/letsencrypt-issuer"
  create_namespace = true

  set = [
    {
      name     = "email"
      value    = var.email
    }
  ]
}
