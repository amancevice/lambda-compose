pkg=$(shell python setup.py --fullname)

lock:
	docker-compose run --rm lock
	docker-compose run --rm -T lock -r > requirements.txt
	docker-compose run --rm -T lock -r -d > requirements-dev.txt

build:
	docker-compose run --rm build -t /var/task --no-deps .
	docker-compose run --rm build -t /opt/python -r requirements.txt

package:
	mkdir -p dist
	docker-compose run --rm -T package > dist/$(pkg).lambda.zip
	docker-compose run --rm -T -w /opt package > dist/$(pkg).layer.zip

deploy:
	docker-compose run --rm deploy sync . s3://my-bucket/path/to/prefix/

test:
	docker-compose run --rm test my_lambda_function.index.handler


clean:
	docker-compose down --volumes
