variable "source_dir" {
  description = "The directory with the lambda function to package"
}

variable "build_dir" {
  # Note: this has to remain required. At the time of writing, using a random_*
  # resource will not work because the random resource won't be created until
  # apply time, which will cause initial plans to fail.
  description = "One will be created with a random name if omitted."
}

variable "output_path" {
  description = "Where to output the zip package to"
}

data "external" "packaging_script" {
  program = ["bash", "${path.module}/bin/package.sh"]

  query = {
    source_dir  = var.source_dir
    build_dir   = var.build_dir
    output_path = var.output_path
  }
}

output "zip_file" {
  value = data.external.packaging_script.result.output_path
}

output "output_sha" {
  value = data.external.packaging_script.result.sha1
}

output "output_base64sha256" {
  value = data.external.packaging_script.result.base64sha256
}

output "output_md5" {
  value = data.external.packaging_script.result.md5
}
