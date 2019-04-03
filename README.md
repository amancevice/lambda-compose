# Application Development for AWS Lambda

Developing Lambda applications for AWS Lambda using Docker.

## Introduction

Lambda is a component of the _serverless_ toolkit that allows execution of code without the headache of server management. Applications are deployed to a sandboxed environment and must complete their task within 15 minutes. This type of behavior is ideal when composing a fleet of microservices that each perform a unit of work.

Developing for Lambda can be a challenge because the Lambda runtime is a walled-garden. Using docker compose, docker volumes, and the `lambci/lambda` images this process can be significantly streamlined.

## Requirements

All runtimes
- [Docker](https://docs.docker.com/install/)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html) (optional)

Python Runtime
- [Python](https://www.python.org)
- [Pipenv](https://pipenv.readthedocs.io/en/latest/#install-pipenv-today) (optional)

NodeJS Runtime
- [node](https://nodejs.org/)
- [npm](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm)

## Development Stages

The development process can be broken down into six stages:
- **Lock** where the full list of dependencies is locked to support deterministic builds
- **Build** where the application's environment is constructed
- **Package** where the application's environment is zipped
- **Deploy** where the application's package(s) are persisted on S3
- **Test** where the application is tested in an environment that nearly replicates the Lambda runtime

# Python Runtime

How to set up your workspace for developing Python Lambdas.

## Setup

Let's begin by creating a simple Python project:

```
/python
├─┬ my_lambda_function/
│ ├── __init__.py
│ └── index.py
├── .env
├── docker-compose.yml
├── Makefile
└── setup.py
```

`my_lambda_function` will contain the Python project.

`.env` will contain environmental variables that might be needed for the application. This file may contain sensitive information so it's important to remember to omit from source control.

`docker-compose.yml` will define our development steps.

`Makefile` will assemble docker-compose steps into stages.

`setup.py` will help define our application package.

A simple `setup.py` might look like this:

```python
# ./setup.py
from setuptools import setup

setup(
    name='my-lambda-function',
    packages=['my_lambda_function'],
    version='0.1.0',
    # Or, using `setuptools_scm`
    # setup_requires=['setuptools_scm'],
    # use_scm_version=True,
)

```

## Lock

_Locking_ in this context is the process of determining the full dependency graph of the project. How this is done is left to the user, but Pipenv is a solid (if controversial) choice.

Begin the process of locking by executing `pipenv lock` at the root of your project. This will create a virtual environment to compute the dependency tree and create two new files in your project:

```
  /python
  ├─┬ my_lambda_function/
  │ ├── __init__.py
  │ └── index.py
  ├── .env
  ├── docker-compose.yml
  ├── Makefile
* ├── Pipfile
* ├── Pipfile.lock
  └── setup.py
```

Let's assume our project will depend on the `pandas` and `requests` libraries. Optionally, include `boto3` in your dev requirements. Update the `Pipfile` to require them:

```toml
# ./Pipfile
[[source]]
name = "pypi"
url = "https://pypi.org/simple"
verify_ssl = true

[dev-packages]
boto3 = "*"

[packages]
pandas = ">=0.24"
requests = ">=2.21"

[requires]
python_version = "3.7"
```

Run `pipenv lock` again to regenerate `Pipfile.lock`.

Once the lock is complete, generate the requirements files:

```bash
pipenv lock --requirements > requirements.txt
pipenv lock --requirements --dev > requirements-dev.txt
```

Your project should now look like the following:

```
  /python
  ├─┬ my_lambda_function/
  │ ├── __init__.py
  │ └── index.py
  ├── .env
  ├── docker-compose.yml
  ├── Makefile
  ├── Pipfile
  ├── Pipfile.lock
* ├── requirements.txt
* ├── requirements-dev.txt
  └── setup.py
```

Update the Makefile with instructions on locking:

```Makefile
# ./Makefile
.PHONY: lock

Pipfile.lock: Pipfile
	pipenv lock
	pipenv lock --requirements > requirements.txt
	pipenv lock --requirements --dev > requirements-dev.txt

lock: Pipfile.lock
```

Run `make lock` to lock your dependencies.

## Build

Now that we have fully locked requirements, we can define our build stage in our compose configuration:

```yaml
# ./docker-compose.yml
version: '3'
services:

  # Build
  build:
    entrypoint: pip install
    image: lambci/lambda:build-python3.7
    volumes:
      - lambda:/var/task
      - layer:/opt/python
      - ./:/tmp
    working_dir: /tmp

volumes:
  lambda:
  layer:
```

Update the Makefile with instructions on building:

```Makefile
# ./Makefile

# (lock tasks omitted for brevity)

build:
	# Install the lambda code to /var/task (with no dependencies)
	docker-compose run --rm build --target /var/task --no-deps .
	# Install the dependency layer to /opt/python
	docker-compose run --rm build --target /opt/python --requirement requirements.txt
```

Run `make build` to install your application to the `lambda` and `layer` volumes.

_Note: Splitting the application and layer in this fashion is not required, but it's a handy way to separate your application logic from its core dependencies.

Assuming your application codebase is small, updating your Lambda function becomes fairly trivial._

## Package

Add a packaging service that simply zips the working directory to stdout.

```yaml
# ./docker-compose.yml
version: '3'
services:

  # (Build stage omitted for brevity)

  # Package
  dist:
    entrypoint: zip -r - .
    image: lambci/lambda:build-python3.7
    volumes:
      - lambda:/var/task
      - layer:/opt/python

volumes:
  lambda:
  layer:
```

Optionally, update the Makefile with instructions on packaging:

```Makefile
# ./Makefile

# (lock/build tasks omitted for brevity)

dist:
	mkdir -p dist
	docker-compose run --rm -T dist > dist/lambda.zip
	docker-compose run --rm -T --workdir /opt dist > dist/layer.zip
```

Run `make dist` to create your zip packages under `./dist`.

## Deploy

Not to be confused with deploying the Lambda, the deploy stage is used to upload your packages to S3.

Update the Makefile with instructions on deploying to S3:

```Makefile
# ./Makefile

# (lock/build/dist tasks omitted for brevity)

deploy:
	docker-compose run --rm -T package | aws s3 cp - s3://my-bucket/path/to/prefix/lambda.zip
	docker-compose run --rm -T --workdir /opt package | aws s3 cp - s3://my-bucket/path/to/prefix/layer.zip
```

Run `make deploy` to stream your zipped packages directly to S3.

## Test

Add your AWS keys to `.env` as well as any other environment variables your application might require.

```bash
# ./.env
AWS_ACCESS_KEY_ID=<aws-access-key-id>
AWS_SECRET_ACCESS_KEY=<aws-secret-access-key>
AWS_DEFAULT_REGION=us-east-1
```

In order to test your application in a Lambda-like runtime, add a test configuration to compose:

```yaml
# ./docker-compose.yml
version: '3'
services:

  # (Build/Package stages omitted for brevity)

  # Test function
  test:
    env_file: .env
    image: lambci/lambda:python3.7
    volumes:
      - lambda:/var/task
      - layer:/opt/python

volumes:
  lambda:
  layer:
```

Run `docker-compose run --rm test path.to.handler '{"example":"payload"}'` to see your application in action!

## Dev

Add a dev section to your compose configuration to develop inside a container:

```yaml
# ./docker-compose.yml
version: '3'
services:

  # (Build/Package/Test stages omitted for brevity)

  # Develop function
  dev:
    command: /bin/bash
    env_file: .env
    image: lambci/lambda:build-python3.7
    volumes:
      - layer:/opt/python
      - ./:/var/task

volumes:
  lambda:
  layer:
```

Run `docker-compose run --rm dev` to enter an interactive shell that closely resembles Lambda.

## Clean

Update your Makefile with a task to clean your environment:

```Makefile
# ./Makefile

# (lock/build/dist/test tasks omitted for brevity)

clean:
	rm -rf dist
	docker-compose down --volumes
```

Run `make clean` to remove any containers, networks, and volumes from your system.

# Full Configuration Examples

A complete compose configuration for reference:

```yaml
# ./docker-compose.yml
version: '3'
services:

  # Build lambda/layer
  build:
    entrypoint: pip install
    image: lambci/lambda:build-python3.7
    volumes:
      - lambda:/var/task
      - layer:/opt/python
      - ./:/tmp
    working_dir: /tmp

  # Package lambda/layer
  dist:
    entrypoint: zip -r - .
    image: lambci/lambda:build-python3.7
    volumes:
      - lambda:/var/task
      - layer:/opt/python

  # Test function
  test:
    env_file: .env
    image: lambci/lambda:python3.7
    volumes:
      - lambda:/var/task
      - layer:/opt/python

  # Develop function
  dev:
    command: /bin/bash
    env_file: .env
    image: lambci/lambda:build-python3.7
    volumes:
      - layer:/opt/python
      - ./:/var/task

volumes:
  lambda:
  layer:
```

A complete Makefile for reference:

```Makefile
# ./Makefile
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
	docker-compose run --rm -T dist > dist/lambda.zip
	docker-compose run --rm -T --workdir /opt dist > dist/layer.zip

deploy:
	docker-compose run --rm -T dist | aws s3 cp - s3://my-bucket/path/to/prefix/lambda.zip
	docker-compose run --rm -T --workdir /opt dist | aws s3 cp - s3://my-bucket/path/to/prefix/layer.zip

clean:
	rm -rf dist
	docker-compose down --volumes
```
