variable "images" {
  default = {
    "3.2-released" = "sles12sp4"
    "3.2-nightly" = "sles12sp4"
    "4.0-released" = "sles15sp1"
    "4.0-nightly" = "sles15sp1"
    "head" = "sles15sp2"
    "uyuni-master" = "opensuse151"
    "uyuni-released" = "opensuse151"
  }
}

resource "libvirt_volume" "server_data_disk" {
  name = "${var.base_configuration["name_prefix"]}${var.name}-server-data-disk"
  size = "${var.repository_disk_size}"
  pool = "${var.data_pool}"
  count = "${var.repository_disk_size > 0 ? 1 : 0}"
}

module "suse_manager" {
  source = "../host"

  base_configuration = "${var.base_configuration}"
  name = "${var.name}"
  use_os_released_updates = "${var.use_os_released_updates}"
  use_os_unreleased_updates = "${var.use_os_unreleased_updates}"
  additional_repos = "${var.additional_repos}"
  additional_repos_only = "${var.additional_repos_only}"
  additional_certs = "${var.additional_certs}"
  additional_packages = "${var.additional_packages}"
  swap_file_size = "${var.swap_file_size}"
  ssh_key_path = "${var.ssh_key_path}"
  gpg_keys = "${var.gpg_keys}"
  ipv6 = "${var.ipv6}"
  connect_to_base_network = true
  connect_to_additional_network = false
  # HACK: work around "conditional operator cannot be used with list values"
  roles = "${split(",", var.register_to_server == "null" ? "suse_manager_server" : "suse_manager_server,minion")}"
  grains = <<EOF

product_version: ${var.product_version}
cc_username: ${var.base_configuration["cc_username"]}
cc_password: ${var.base_configuration["cc_password"]}
channels: [${join(",", var.channels)}]
cloned_channels: ${var.cloned_channels}
mirror: ${var.base_configuration["mirror"]}
iss_master: ${var.iss_master}
iss_slave: ${var.iss_slave}
server: ${var.register_to_server}
auto_connect_to_master: ${var.auto_register}
susemanager:
  activation_key: ${var.activation_key}
smt: ${var.smt}
server_username: ${var.server_username}
server_password: ${var.server_password}
disable_firewall: ${var.disable_firewall}
allow_postgres_connections: ${var.allow_postgres_connections}
unsafe_postgres: ${var.unsafe_postgres}
java_debugging: ${var.java_debugging}
skip_changelog_import: ${var.skip_changelog_import}
browser_side_less: ${var.browser_side_less}
create_first_user: ${var.create_first_user}
mgr_sync_autologin: ${var.mgr_sync_autologin}
create_sample_channel: ${var.create_sample_channel}
create_sample_activation_key: ${var.create_sample_activation_key}
create_sample_bootstrap_script: ${var.create_sample_bootstrap_script}
publish_private_ssl_key: ${var.publish_private_ssl_key}
disable_download_tokens: ${var.disable_download_tokens}
auto_accept: ${var.auto_accept}
monitored: ${var.monitored}
pts: ${var.pts}
pts_minion: ${var.pts_minion}
pts_locust: ${var.pts_locust}
pts_system_count: ${var.pts_system_count}
pts_system_prefix: ${var.pts_system_prefix}
apparmor: ${var.apparmor}
from_email: ${var.from_email}
traceback_email: ${var.traceback_email}
saltapi_tcpdump: ${var.saltapi_tcpdump}
repository_disk_size: ${var.repository_disk_size}
repository_disk_device: vdb

EOF

  // Provider-specific variables
  image = "${var.image == "default" ? lookup(var.images, var.product_version) : var.image}"
  memory = "${var.memory}"
  vcpu = "${var.vcpu}"
  running = "${var.running}"
  mac = "${var.mac}"

  // HACK: Terraform 0.11 ternary operator is not short-circuiting
  // https://github.com/hashicorp/terraform/issues/11566
  // example by https://github.com/coreos/tectonic-installer/commit/0f209b31b169ce129ba457096b23792f6601d66e#diff-17708827fa84c637698cd840c01710c9R16
  additional_disk = "${slice(
    list(map("volume_id", join("",libvirt_volume.server_data_disk.*.id))),
    0,
    var.repository_disk_size > 0 ? 1 : 0
  )}"
}

output "configuration" {
  value = {
    id = "${module.suse_manager.configuration["id"]}"
    hostname = "${module.suse_manager.configuration["hostname"]}"
    product_version = "${var.product_version}"
    username = "${var.server_username}"
    password = "${var.server_password}"
  }
}
