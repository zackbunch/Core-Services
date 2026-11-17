variable "groups" {
  description = "Groups to manage, keyed by a stable Terraform identifier. Set parent_id to create a group under an existing GitLab group."
  type = map(object({
    name             = string
    path             = string
    parent_id        = optional(number)
    visibility_level = optional(string, "private")
  }))
  default = {}
}

variable "subgroups" {
  description = "Subgroups of groups managed by this configuration. parent_key must be a key in groups."
  type = map(object({
    name             = string
    path             = string
    parent_key       = string
    visibility_level = optional(string, "private")
  }))
  default = {}

  validation {
    condition     = alltrue([for group in values(var.subgroups) : contains(keys(var.groups), group.parent_key)])
    error_message = "Each subgroup parent_key must identify an entry in groups."
  }
}
