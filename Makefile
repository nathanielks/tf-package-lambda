

deps :
	brew tap orf/brew
	brew install deterministic-zip jq

EXPECTED = '{"output_base64sha256":"2neNhsuqJrlSIiHmrgN7mAOMZrcGxOJnUTH150aOb/8=","output_md5":"c38207dab3869026a079a498d55ea7e4","output_sha":"91575e22db67f898778d8aabb9182afb641b967a","zip_file":"/tmp/terraform-package-lambda.zip"}'

test-all:
	cd test/; \
		terraform init;\
		terraform apply;\
		echo Expecting: $(EXPECTED);\
		bash -c "[[ \"$$(terraform output -json 'module')\" == $(EXPECTED) ]] && echo Test passed || ( echo 'Resulting output did not match expected output.' && exit 1)"
