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

data "archive_file" "zip" {
  type        = "zip"
  source_dir  = data.external.packaging_script.result.packaged_dir
  output_path = var.output_path
}

output "zip_file" {
  value = var.output_path
}

output "output_sha" {
  value = filesha1(data.external.packaging_script.result.output_path)
}

output "output_base64sha256" {
  value = filebase64sha256(data.external.packaging_script.result.output_path)
}

output "output_md5" {
  value = filemd5(data.external.packaging_script.result.output_path)
}

