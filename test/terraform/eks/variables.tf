variable "region" {
  default     = "us-west-2"
  description = "AWS region"
}

variable "cluster_count" {
  default     = 1
  description = "The number of Kubernetes clusters to create."
}