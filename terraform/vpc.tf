module "vpc" {
  source   = "aws-ia/vpc/aws"
  version = ">= 4.1.0"

  name       = "${var.environment}-${var.name}-vpc"
  cidr_block = "10.0.0.0/20"
  az_count   = 3

  subnets = {
    public = {
      netmask                   = 24
      nat_gateway_configuration = "all_azs" // IRL, multi AZ
    }

    private = {
      netmask      = 24
      connect_to_public_natgw = true
    }
  }

  vpc_flow_logs = {
    log_destination_type = "cloud-watch-logs"
    retention_in_days    = 180
  }
}
