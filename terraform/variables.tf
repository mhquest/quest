variable "profile" {
  type = string
}

variable "region" {
  type = string
}

variable "tags" {
  type    = map(any)
  default = {}
}

variable "availability_zones" {
  type    = list(any)
  default = []
}

variable "name" {
  type    = string
  default = "quest"
}

variable "environment" {
  type = string
}

variable "domain_name" {
  type = string
}
