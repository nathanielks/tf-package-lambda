

deps :
	brew tap orf/brew
	brew install deterministic-zip jq

EXPECTED = '{"output_base64sha256":"amgGT29heD729wotF4LYvaK7VfzTyLpptjSvBQA1uOA=","output_md5":"f77a0da7cb505656eb7a0809c76afbe2","output_sha":"1f2f31ab9518828db01645632509184864496d7a","zip_file":"/tmp/terraform-package-lambda.zip"}'

test-all:
	cd test/; \
		terraform init;\
		terraform apply;\
		echo Expecting: $(EXPECTED);\
		bash -c "[[ \"$$(terraform output -json 'module')\" == $(EXPECTED) ]] && echo Test passed || ( echo 'Resulting output did not match expected output.' && exit 1)"
