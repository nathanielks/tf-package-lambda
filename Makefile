

deps :
	brew tap orf/brew
	brew install deterministic-zip jq

EXPECTED = '{"output_base64sha256":"1IraZz0wzGXBrK/wmQiJRt3PNiInms+xl4kTDkm9fnw=","output_md5":"8a11e17788d204c3b84a3e3fa9a902b9","output_sha":"11f5305c5f9d30c0bf2fb0fb840b9edad226ff9e","zip_file":"/tmp/terraform-package-lambda.zip"}'

test-prep:
	cd test/; \
		terraform init;\
		terraform apply;\

test-all:
	cd test/; \
		echo Expecting: $(EXPECTED);\
		RESULT=$$(terraform output -json 'module');\
		[[ "$$RESULT" == $(EXPECTED) ]] && echo Test passed || ( echo 'Resulting output did not match expected output.' && exit 1)
