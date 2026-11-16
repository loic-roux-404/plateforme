
terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

# provider "github" is configured by the root module (tf-root-paas) — a
# module-local provider config forbids count/for_each on module calls.
