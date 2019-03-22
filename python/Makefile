pkg:=$(shell python setup.py --fullname)

.PHONY: lock build deploy test

Pipfile.lock: Pipfile
	pipenv lock
	pipenv lock --requirements > requirements.txt
	pipenv lock --requirements --dev > requirements-dev.txt

lock: Pipfile.lock

build:
	docker-compose run --rm build -t /var/task --no-deps .
	docker-compose run --rm build -t /opt/python -r requirements.txt

dist: build
	mkdir -p dist
	docker-compose run --rm -T dist > dist/$(pkg).lambda.zip
	docker-compose run --rm -T -w /opt dist > dist/$(pkg).layer.zip

deploy:
	docker-compose run --rm -T package | aws s3 cp - s3://my-bucket/path/to/prefix/$(pkg).lambda.zip
	docker-compose run --rm -T -w /opt package | aws s3 cp - s3://my-bucket/path/to/prefix/$(pkg).layer.zip

test:
	docker-compose run --rm test my_lambda_function.index.handler

clean:
	rm -rf dist
	docker-compose down --volumes
