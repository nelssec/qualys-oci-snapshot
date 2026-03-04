output "application_id" {
  value = oci_functions_application.scanner_app.id
}

output "function_ids" {
  description = "Map of function names to OCIDs"
  value = {
    oci_sdk_wrapper          = oci_functions_function.oci_sdk_wrapper.id
    data_formatter           = oci_functions_function.data_formatter.id
    nosql_wrapper            = oci_functions_function.nosql_wrapper.id
    create_scan_status       = oci_functions_function.create_scan_status.id
    generate_scan_chunks     = oci_functions_function.generate_scan_chunks.id
    fetch_inventory_chunks   = oci_functions_function.fetch_inventory_chunks.id
    generate_scan_params     = oci_functions_function.generate_scan_params.id
    app_config_store         = oci_functions_function.app_config_store.id
    stack_cleanup            = oci_functions_function.stack_cleanup.id
    image_cleanup            = oci_functions_function.image_cleanup.id
    discovery_worker         = oci_functions_function.discovery_worker.id
    discovery_scheduler      = oci_functions_function.discovery_scheduler.id
    image_discovery_scheduler = oci_functions_function.image_discovery_scheduler.id
    event_task_scheduler     = oci_functions_function.event_task_scheduler.id
    scheduled_fn_check       = oci_functions_function.scheduled_fn_check.id
    post_process_scan        = oci_functions_function.post_process_scan.id
    process_scan_files       = oci_functions_function.process_scan_files.id
    on_demand_scan           = oci_functions_function.on_demand_scan.id
    download_to_storage      = oci_functions_function.download_to_storage.id
    update_function_code     = oci_functions_function.update_function_code.id
    create_bucket            = oci_functions_function.create_bucket.id
    qflow_api                = oci_functions_function.qflow_api.id
    proxy_instance           = oci_functions_function.proxy_instance.id
  }
}

output "function_invoke_endpoints" {
  description = "Map of function names to invoke endpoints"
  value = {
    oci_sdk_wrapper          = oci_functions_function.oci_sdk_wrapper.invoke_endpoint
    data_formatter           = oci_functions_function.data_formatter.invoke_endpoint
    nosql_wrapper            = oci_functions_function.nosql_wrapper.invoke_endpoint
    create_scan_status       = oci_functions_function.create_scan_status.invoke_endpoint
    generate_scan_chunks     = oci_functions_function.generate_scan_chunks.invoke_endpoint
    fetch_inventory_chunks   = oci_functions_function.fetch_inventory_chunks.invoke_endpoint
    generate_scan_params     = oci_functions_function.generate_scan_params.invoke_endpoint
    app_config_store         = oci_functions_function.app_config_store.invoke_endpoint
    stack_cleanup            = oci_functions_function.stack_cleanup.invoke_endpoint
    image_cleanup            = oci_functions_function.image_cleanup.invoke_endpoint
    discovery_worker         = oci_functions_function.discovery_worker.invoke_endpoint
    discovery_scheduler      = oci_functions_function.discovery_scheduler.invoke_endpoint
    image_discovery_scheduler = oci_functions_function.image_discovery_scheduler.invoke_endpoint
    event_task_scheduler     = oci_functions_function.event_task_scheduler.invoke_endpoint
    scheduled_fn_check       = oci_functions_function.scheduled_fn_check.invoke_endpoint
    post_process_scan        = oci_functions_function.post_process_scan.invoke_endpoint
    process_scan_files       = oci_functions_function.process_scan_files.invoke_endpoint
    on_demand_scan           = oci_functions_function.on_demand_scan.invoke_endpoint
    download_to_storage      = oci_functions_function.download_to_storage.invoke_endpoint
    update_function_code     = oci_functions_function.update_function_code.invoke_endpoint
    create_bucket            = oci_functions_function.create_bucket.invoke_endpoint
    qflow_api                = oci_functions_function.qflow_api.invoke_endpoint
    proxy_instance           = oci_functions_function.proxy_instance.invoke_endpoint
  }
}
