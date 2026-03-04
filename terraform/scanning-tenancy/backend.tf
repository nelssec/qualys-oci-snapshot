terraform {
  backend "http" {
    # OCI Resource Manager backend
    # When using Resource Manager, this is configured automatically
    # For CLI usage, configure with:
    #   address        = "https://objectstorage.<region>.oraclecloud.com/p/<par>/n/<namespace>/b/<bucket>/o/terraform.tfstate"
    #   update_method  = "PUT"
  }
}
