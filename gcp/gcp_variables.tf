variable "gcp_credentials" {
    type = string
    default = ""
}
variable "gcp_region" {
    type = string
    default = ""
}
variable "gcp_project" {
    type = string
    default = ""
}

variable "gcp_user" {
    type = string
    default = ""
}

variable "gcp_email" {
    type = string
    default = ""
}
variable "gcp_privatekeypath" {
    type = string
    default = "~/.ssh/google_compute_engine"
}

variable "gcp_publickeypath" {
    type = string
    default = "~/.ssh/google_compute_engine.pub"
}