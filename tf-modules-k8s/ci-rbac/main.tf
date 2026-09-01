# CI RBAC: an "extended edit" aggregated ClusterRole + per-namespace bindings.
#
# Design:
# - "extra" rules (CRDs, APIServices, clusterroles/bindings CRUD, ARC CRD group)
#   live in their own labeled ClusterRole. They are NOT inlined in the aggregated
#   role because the K8s controllers rewrite the rules of aggregated roles.
# - the aggregated ClusterRole selects both:
#     * rbac.authorization.k8s.io/aggregate-to-edit: "true"  -> inherits everything
#       the upstream `edit` role has (incl. third-party aggregated rules, e.g.
#       cert-manager), staying in sync as the cluster evolves;
#     * our extra label -> the CI-specific powers.
# - per-namespace RoleBindings bind the aggregated role for every CI namespace.
#
# Note: binding a ClusterRole through a namespaced RoleBinding scopes the
# aggregated (cluster-wide) rules to that namespace, which is exactly what we
# want for CI deploys.

# --- Extra CI powers (selected by the aggregated role via its label) ---

resource "kubernetes_cluster_role_v1" "extra" {
  metadata {
    name = "${var.role_name}-extra"
    labels = {
      # selected by the aggregated role below
      "k3s-paas.loic-roux-404.com/aggregate-to-ci-edit" = "true"
    }
  }

  # CRDs and APIServices CRUD (e.g. installing the ARC CRDs + webhook APIService)
  rule {
    api_groups = ["apiextensions.k8s.io"]
    resources  = ["customresourcedefinitions"]
    verbs      = ["create", "delete", "deletecollection", "get", "list", "patch", "update", "watch"]
  }

  rule {
    api_groups = ["apiregistration.k8s.io"]
    resources  = ["apiservices"]
    verbs      = ["create", "delete", "deletecollection", "get", "list", "patch", "update", "watch"]
  }

  # ClusterRole/ClusterRoleBinding CRUD (e.g. charts that create their own RBAC,
  # like the ARC controller service account)
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["clusterroles", "clusterrolebindings"]
    verbs      = ["create", "delete", "deletecollection", "get", "list", "patch", "update", "watch"]
  }

  # ARC (actions-runner-controller) CRD group + cert-manager certificates
  rule {
    api_groups = ["actions.github.com"]
    resources  = ["*"]
    verbs      = ["*"]
  }

  rule {
    api_groups = ["cert-manager.io"]
    resources  = ["certificates"]
    verbs      = ["create", "delete", "deletecollection", "get", "list", "patch", "update", "watch"]
  }
}

# --- The aggregated "extended edit" ClusterRole ---

resource "kubernetes_cluster_role_v1" "aggregated" {
  metadata {
    name = var.role_name
  }

  # rules are server-managed by the K8s aggregation controllers:
  # union of `edit` (and everything aggregated into it) + the extra role above.
  aggregation_rule {
    cluster_role_selectors {
      match_labels = {
        "rbac.authorization.k8s.io/aggregate-to-edit" = "true"
      }
    }

    cluster_role_selectors {
      match_labels = {
        "k3s-paas.loic-roux-404.com/aggregate-to-ci-edit" = "true"
      }
    }
  }
}

# --- Namespaces + per-namespace bindings ---

data "kubernetes_all_namespaces" "all" {}

locals {
  existing = toset(data.kubernetes_all_namespaces.all.namespaces)
  missing  = var.create_namespaces ? setsubtract(toset(var.namespaces), local.existing) : toset([])
}

resource "kubernetes_namespace_v1" "ci" {
  for_each = local.missing

  metadata {
    name = each.value
  }
}

resource "kubernetes_role_binding_v1" "ci_edit" {
  for_each = toset(var.namespaces)

  metadata {
    name      = "${var.role_name}-ci"
    namespace = each.value
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.aggregated.metadata[0].name
  }

  dynamic "subject" {
    for_each = var.subjects
    content {
      kind      = subject.value.kind
      name      = subject.value.name
      api_group = subject.value.api_group
    }
  }
}

output "cluster_role_name" {
  value       = kubernetes_cluster_role_v1.aggregated.metadata[0].name
  description = "Name of the aggregated extended-edit ClusterRole."
}

output "namespaces_bound" {
  value       = keys(kubernetes_role_binding_v1.ci_edit)
  description = "Namespaces where the CI role is bound."
}
