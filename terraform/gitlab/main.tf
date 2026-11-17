terraform {
  required_version = ">= 1.9.0"

  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "~> 18.0"
    }
  }
}

# Authentication and the GitLab endpoint are supplied through environment variables.
provider "gitlab" {}

resource "gitlab_group" "groups" {
  for_each = var.groups

  name             = each.value.name
  path             = each.value.path
  parent_id        = each.value.parent_id
  visibility_level = each.value.visibility_level
}

resource "gitlab_group" "subgroups" {
  for_each = var.subgroups

  name             = each.value.name
  path             = each.value.path
  parent_id        = gitlab_group.groups[each.value.parent_key].id
  visibility_level = each.value.visibility_level
}
