pkg:=$(shell python setup.py --fullname)

.PHONY: lock build deploy clean

Pipfile.lock: Pipfile
	pipenv lock
	pipenv lock --requirements > requirements.txt
	pipenv lock --requirements --dev > requirements-dev.txt

lock: Pipfile.lock

build:
	docker-compose run --rm build --target /var/task --no-deps --upgrade .
	docker-compose run --rm build --target /opt/python --requirement requirements.txt

dist:
	mkdir -p dist
	docker-compose run --rm -T dist > dist/$(pkg).lambda.zip
	docker-compose run --rm -T --workdir /opt dist > dist/$(pkg).layer.zip

deploy:
	docker-compose run --rm -T dist | aws s3 cp - s3://my-bucket/path/to/prefix/$(pkg).lambda.zip
	docker-compose run --rm -T --workdir /opt dist | aws s3 cp - s3://my-bucket/path/to/prefix/$(pkg).layer.zip

clean:
	rm -rf dist
	docker-compose down --volumes
