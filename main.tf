# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY TILLER INTO A NEW NAMESPACE
# These templates show an example of how to deploy Tiller following security best practices. This entails:
# - Creating a Namespace and ServiceAccount for Tiller
# - Creating a separate Namespace for the resources to go into
# - Using kubergrunt to deploy Tiller with TLS management
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CONFIGURE OUR KUBERNETES CONNECTIONS
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

provider "kubernetes" {
  config_context = "${var.kubectl_config_context_name}"
  config_path    = "${var.kubectl_config_path}"
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE THE NAMESPACE WITH RBAC ROLES AND SERVICE ACCOUNT
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

module "tiller_namespace" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-kubernetes-helm.git//modules/k8s-namespace?ref=v0.1.0"
  source = "./modules/k8s-namespace"

  name = "${var.tiller_namespace}"
}

module "resource_namespace" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-kubernetes-helm.git//modules/k8s-namespace?ref=v0.1.0"
  source = "./modules/k8s-namespace"

  name = "${var.resource_namespace}"
}

module "tiller_service_account" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-kubernetes-helm.git//modules/k8s-service-account?ref=v0.1.0"
  source = "./modules/k8s-service-account"

  name           = "${var.service_account_name}"
  namespace      = "${module.tiller_namespace.name}"
  num_rbac_roles = 2

  rbac_roles = [
    {
      name      = "${module.tiller_namespace.rbac_tiller_metadata_access_role}"
      namespace = "${module.tiller_namespace.name}"
    },
    {
      name      = "${module.resource_namespace.rbac_tiller_resource_access_role}"
      namespace = "${module.resource_namespace.name}"
    },
  ]

  labels = {
    app = "tiller"
  }
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY TILLER
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

resource "null_resource" "tiller" {
  provisioner "local-exec" {
    command = "kubergrunt helm deploy ${local.kubectl_config_options} --service-account ${module.tiller_service_account.name} --resource-namespace ${module.resource_namespace.name} --tiller-namespace ${module.tiller_namespace.name} ${local.tls_config} ${local.client_tls_config} --helm-home ${local.helm_home_with_default} ${local.configure_args}"
  }

  provisioner "local-exec" {
    command = "kubergrunt helm undeploy ${local.kubectl_config_options} --helm-home ${local.helm_home_with_default} --tiller-namespace ${module.tiller_namespace.name} ${local.undeploy_args}"
    when    = "destroy"
  }
}