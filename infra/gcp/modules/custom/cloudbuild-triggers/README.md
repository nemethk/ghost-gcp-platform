# Simple Terraform provisioning pipeline

You can use this module to create two Cloud Build triggers that can be used for provisioning further infrastructure elements with Terraform.

It creates a plan trigger that will output the Terraform plan to a GCS bucket where SRE can review it.

This plan will then be used by the Terraform apply trigger.

By default, the name of the Terraform plan file on GCS will be the commit hash, and the apply trigger will look for it by this name. If the plan trigger is re-executed for that hash, the file is overwritten. If you wish to keep multiple plans triggered from a single commit hash (due to changed infrastructure for example), you can provide the `include_build_id` parameter. In this case, you'll have to provide the Cloud Build build id of the plan execution as an input to the apply trigger.

The module now works with Github repositories connected to Cloud Source Repositories. Setting this up is a manual prerequisite.

### Enable APIs
* `storage.googleapis.com`
* `cloudbuild.googleapis.com`

 <!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | n/a |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_cloudbuild_trigger.tf-apply-trigger](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudbuild_trigger) | resource |
| [google_cloudbuild_trigger.tf-plan-trigger](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudbuild_trigger) | resource |
| [google_storage_bucket.gcs-bucket-tf-plans](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) | resource |
| [random_id.bucket_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_branches_to_apply_regex"></a> [branches\_to\_apply\_regex](#input\_branches\_to\_apply\_regex) | n/a | `string` | `"main"` | no |
| <a name="input_branches_to_plan_regex"></a> [branches\_to\_plan\_regex](#input\_branches\_to\_plan\_regex) | n/a | `string` | `".*"` | no |
| <a name="input_bucket_name_prefix"></a> [bucket\_name\_prefix](#input\_bucket\_name\_prefix) | n/a | `string` | `"bucket-for-tf-plans"` | no |
| <a name="input_github_name"></a> [github\_name](#input\_github\_name) | n/a | `string` | n/a | yes |
| <a name="input_github_owner"></a> [github\_owner](#input\_github\_owner) | n/a | `string` | n/a | yes |
| <a name="input_include_build_id"></a> [include\_build\_id](#input\_include\_build\_id) | Switching this variable to true will require build id to apply a terraform plan | `bool` | `false` | no |
| <a name="input_plan_retention_days"></a> [plan\_retention\_days](#input\_plan\_retention\_days) | The number of days terraform plan files are kept in GCS | `number` | `30` | no |
| <a name="input_project"></a> [project](#input\_project) | n/a | `string` | n/a | yes |
| <a name="input_storage_location"></a> [storage\_location](#input\_storage\_location) | n/a | `string` | `"EU"` | no |
| <a name="input_working_directory"></a> [working\_directory](#input\_working\_directory) | The path of the root terraform module inside the configured git repository | `string` | `"."` | no |
| <a name="trigger_name_suffix"></a> [trigger\_name\_suffix](#input\_trigger\_name\_suffix) | Trigger name suffix for multi-project infrastructures | `string` | "ops" | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_plan_repository_name"></a> [plan\_repository\_name](#output\_plan\_repository\_name) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

