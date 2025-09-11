variable "vpc_id"             { description = "VPC ID (optional; read from Lab 01 if empty)" type = string default = "" }
variable "private_subnet_ids" { description = "Private subnet IDs (optional; read from Lab 01 if empty)" type = list(string) default = [] }
variable "app_sg_id"          { description = "App SG ID (source) (optional; read from Lab 07 if empty)" type = string default = "" }
variable "node_type"          { description = "Redis node type" type = string default = "cache.t4g.micro" }
