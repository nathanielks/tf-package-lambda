module "lambda_src" {
  source = "../"

  source_dir  = "${path.module}/src"
  build_dir   = "/tmp/terraform-package-lambda"
  output_path = "/tmp/terraform-package-lambda.zip"
}

# create a file so as to trigger changes in Terraform Cloud
resource "local_file" "foo" {
  content  = "foo!"
  filename = "/tmp/foo.bar"
}

output "lambda_src" {
  value = module.lambda_src
}
