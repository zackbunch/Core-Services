output "groups" {
  description = "Managed groups and subgroups, keyed by their configuration keys."
  value = {
    groups = {
      for key, group in gitlab_group.groups : key => {
        id        = group.id
        full_path = group.full_path
        web_url   = group.web_url
      }
    }
    subgroups = {
      for key, group in gitlab_group.subgroups : key => {
        id        = group.id
        full_path = group.full_path
        web_url   = group.web_url
      }
    }
  }
}
