

deps :
	brew tap orf/brew
	brew install deterministic-zip jq

EXPECTED = '{"output_base64sha256":"RcVBIuZ4fgCmMc+IsN6OXrSqwEVb1V8PvS+tIu+FmoA=","output_md5":"fb584cbbc5248b3823bfa1a688dc7728","output_sha":"c65aed682f69247ee53643ef93fdb4c662890d2e","zip_file":"/tmp/terraform-package-lambda.zip"}'

test-all:
	cd test/; \
		terraform init;\
		terraform apply -auto-approve;\
		echo Expecting: $(EXPECTED);\
		bash -c "[[ \"$$(terraform output -json 'lambda_src')\" == $(EXPECTED) ]] && echo Test passed || ( echo 'Resulting output did not match expected output.' && exit 1)"
