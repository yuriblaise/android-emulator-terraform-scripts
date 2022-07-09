variable "gcp_credentials" {
    type = string
}
variable "gcp_region" {
    type = string
}
variable "gcp_project" {
    type = string
}

variable "gcp_user" {
    type = string
}
variable "gcp_email" {
    type = string
}
variable "gcp_privatekeypath" {
    type = string
    default = "~/.ssh/google_compute_engine"
}
variable "gcp_publickeypath" {
    type = string
    default = "~/.ssh/google_compute_engine.pub"
}