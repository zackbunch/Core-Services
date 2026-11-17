# GitLab groups with Terraform

This configuration manages groups and one level of subgroups. It defaults to
creating nothing. It can target the local GitLab lab or another GitLab instance.

## Setup

1. Start GitLab and trust Caddy's local CA if using the local lab; see the root
   README. Confirm HTTPS works from the machine running Terraform.
2. Create a GitLab personal access token with the `api` scope. Its user must
   have permission to create groups in the desired location. Use a dedicated,
   least-privileged account when practical.
3. In this directory, copy `terraform.tfvars.example` to `terraform.tfvars`
   and edit it. The example names are placeholders, not existing groups.
4. Set credentials in your shell (do not commit the token):

   ```bash
   export GITLAB_BASE_URL="https://gitlab.localhost/api/v4/"
   export GITLAB_TOKEN="your-token"
   terraform init
   terraform plan
   terraform apply
   ```

For GitLab.com, omit `GITLAB_BASE_URL`. Do not bypass TLS verification; trust
the appropriate CA instead. Top-level group creation may be restricted by your
GitLab instance. To create a group beneath an existing group, set its
`parent_id`; use `subgroups` for children of groups managed here.

## Existing groups and state

Import existing groups before applying to avoid attempting to recreate them.
For example, after adding the matching configuration:

```bash
terraform import 'gitlab_group.groups["platform"]' 'existing-group-path'
terraform plan
```

Review the plan carefully: Terraform may change existing settings to match the
configuration. Renaming a map key changes its Terraform address; use a
`moved` block or `terraform state mv` to retain the existing group.

By default Terraform stores state locally in `terraform.tfstate`. State can
contain sensitive information and must not be committed. Back it up securely.
For shared use, configure a secure remote backend with encryption, access
controls, and locking before collaborating. Protect the state and provider
credentials in CI as well. Removing a group from configuration can destroy it
and its contents; always review plans before applying.
