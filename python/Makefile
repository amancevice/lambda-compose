pkg:=$(shell python setup.py --fullname)

.PHONY: lock build deploy

Pipfile.lock: Pipfile
	pipenv lock
	pipenv lock --requirements > requirements.txt
	pipenv lock --requirements --dev > requirements-dev.txt

lock: Pipfile.lock requirements.txt requirements-dev.txt

build:
	docker-compose run --rm build -t /var/task --no-deps .
	docker-compose run --rm build -t /opt/python -r requirements.txt

deploy:
	docker-compose run --rm -T package | aws s3 cp - s3://my-bucket/path/to/prefix/$(pkg).lambda.zip
	docker-compose run --rm -T -w /opt package | aws s3 cp - s3://my-bucket/path/to/prefix/$(pkg).layer.zip

test:
	docker-compose run --rm test my_lambda_function.index.handler

clean:
	docker-compose down --volumes
