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

variable "ingress_nginx_version" {
  type        = string
  default     = "4.12.1"
}

variable "cert_manager_version" {
  type        = string
  default     = "1.17.1"
}

variable "generate_ingress_dhparam" {
  type        = bool
  description = "Generate Diffie-Hellman key for ingress"
}

variable "ingressNginxLoadBalancerIPsByName" {
  type        = map(string)
  default     = {}
  description = "(Optional) Map of NGINX ingress load balancer IP addresses. Key is ingress nginx controller name and value the IP address."
}

variable "email" {
  type = string
  description = "Email address for DevOps support."
}

variable "resources" {
  type = object({
    ingressNginxControllers = optional(list(object({
      name = string
      class = string
      replicas = number
      metricsEnabled = optional(bool)
      maxmindLicenseKey = optional(string)
      configMap = optional(map(string))
      tcpServices = map(string)
      udpServices = map(string)
    })))
    certManager = optional(object({
      enabled = bool
    }))
  })
  description = "Resources as JSON (see README.md). You can read values from a YAML file with yamldecode()."
}
