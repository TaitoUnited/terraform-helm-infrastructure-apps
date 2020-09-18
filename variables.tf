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

variable "ingress_nginx_version" {
  type        = string
  default     = "3.1.0"
}

variable "cert_manager_version" {
  type        = string
  default     = "1.0.1"
}

variable "pod_security_policy_enabled" {
  type        = bool
  description = "True if pod security policy is enabled in Kubernetes cluster"
}

variable "ingressNginxLoadBalancerIPs" {
  type        = list(string)
  default     = []
  description = "(Optional) NGINX ingress load balancer IP addresses"
}

variable "email" {
  type = string
  description = "Email address for DevOps support."
}

variable "resources" {
  type = object({
    ingressNginxControllers = list(object({
      name = string
      class = string
      replicas = number
      metricsEnabled = bool
      maxmindLicenseKey = string
      configMap = map(string)
      tcpServices = map(string)
      udpServices = map(string)
    }))
    certManager = object({
      enabled = bool
    })
    istio = object({
      enabled = bool
    })
    knative = object({
      enabled = bool
    })
    falco = object({
      enabled = bool
    })
    jaeger = object({
      enabled = bool
    })
    sentry = object({
      enabled = bool
    })
    jenkinsx = object({
      enabled = bool
    })
  })
  description = "Resources as JSON (see README.md). You can read values from a YAML file with yamldecode()."
}
