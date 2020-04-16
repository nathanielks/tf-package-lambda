## Terraform Package Lambda <img src="https://circleci.com/gh/nathanielks/terraform-package-lambda/tree/master.svg?style=svg&circle-token=40f7dffce792f6d56be198c82a7e5d31056a8aa0" alt="Build status">

This module runs `npm ci` in an isolated directory and `zip`'s the result in preparation for upload to AWS Lambda. The resulting zip file is produced in a deterministic way that will be consistent across multiple Nix platforms.

## Dependencies

Install its dependencies:

```
brew tap orf/brew
brew install deterministic-zip jq coreutils
```

Additionally, you will need `npm` and `rsync`. It's assumed you have these already on your system.

## Usage

Assuming a file structure like:

```
project-dir/               # → Root folder for the project
├── main.tf                # → Terraform configuration
├── files/lambda/          # → The directory containing the lambda function
├── files/lambda/index.js
└── files/lambda/package.json
```

And this configuration:

```hcl
module "lambda_zip" {
  source = "github.com/nathanielks/tf-package-lambda"

  source_dir  = "${path.module}/files/lambda"
  output_path = "${path.module}/files/packaged.zip"
}
```

Then a packaged zip would be produced at `project-dir/files/packaged.zip`.

Can be used in conjunction with a lambda function resource like so:

```hcl
module "lambda_zip" {
  source = "github.com/nathanielks/tf-package-lambda"

  source_dir  = "${path.module}/files/lambda"
  output_path = "${path.module}/files/packaged.zip"
}

resource "aws_lambda_function" "mod" {
  filename = "${module.lambda_zip.zip_file}"

  source_code_hash = "${module.lambda_zip.output_base64sha256}"

  function_name = "some-lambda-function"
  description   = "Lambda code for monitoring URL's and deregistering instances when they fail a healthcheck."

  # ... additional config
}
```
