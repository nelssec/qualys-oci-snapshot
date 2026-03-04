# API Gateway Module - POST /events endpoint for event forwarding

resource "oci_apigateway_gateway" "scanner_gw" {
  compartment_id = var.compartment_id
  endpoint_type  = "PUBLIC"
  subnet_id      = var.subnet_id
  display_name   = "snapshot-scanner-api-gw"

  freeform_tags = var.common_tags
}

resource "oci_apigateway_deployment" "events_deployment" {
  compartment_id = var.compartment_id
  gateway_id     = oci_apigateway_gateway.scanner_gw.id
  path_prefix    = "/v1"
  display_name   = "snapshot-scanner-events"

  specification {
    request_policies {
      authentication {
        type                         = "CUSTOM_AUTHENTICATION"
        is_anonymous_access_allowed  = false
        function_id                  = var.auth_function_id

        validation_failure_policy {
          type                 = "MODIFY_RESPONSE"
          response_code        = "401"
          response_message     = "Unauthorized"
        }
      }

      rate_limiting {
        rate_in_requests_per_second = var.rate_limit_rps
        rate_key                    = "CLIENT_IP"
      }
    }

    routes {
      path    = "/events"
      methods = ["POST"]

      backend {
        type        = "ORACLE_FUNCTIONS_BACKEND"
        function_id = var.event_task_scheduler_function_id
      }

      request_policies {
        body_validation {
          content {
            media_type      = "application/json"
            validation_type = "NONE"
          }
          required        = true
          validation_mode = "ENFORCING"
        }
      }
    }

    routes {
      path    = "/functions/{functionName}"
      methods = ["POST"]

      backend {
        type        = "ORACLE_FUNCTIONS_BACKEND"
        function_id = var.oci_sdk_wrapper_function_id
      }
    }

    routes {
      path    = "/health"
      methods = ["GET"]

      backend {
        type = "STOCK_RESPONSE_BACKEND"
        body = jsonencode({ status = "healthy", service = "snapshot-scanner" })
        status = 200
        headers {
          name  = "Content-Type"
          value = "application/json"
        }
      }
    }
  }

  freeform_tags = var.common_tags
}
