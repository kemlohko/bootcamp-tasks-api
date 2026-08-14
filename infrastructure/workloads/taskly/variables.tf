variable "developer_name" {
  type = string
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "db_username" {
  type      = string
  sensitive = true
  default   = "taskly_admin"
}

variable "db_name" {
  type = string
  default = "taskly"
}

variable "hosted_zone_id" {
  type    = string
  default = "Z042372728MB5VI4H04IG" # ironlabs.online
}