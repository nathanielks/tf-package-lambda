module "test" {
  source = "../"

  source_dir  = "${path.module}/src"
  build_dir   = "/tmp/terraform-package-lambda"
  output_path = "/tmp/terraform-package-lambda.zip"
}

output "module" {
  value = module.test
}
