output "git_url" {
  description = "Repository every environment's Flux reconciles from — should be identical across all three."
  value = {
    test       = module.test.git_url
    acceptance = module.acceptance.git_url
    production = module.production.git_url
  }
}
