from setuptools import setup

setup(
    name='my-lambda-function',
    packages=['my_lambda_function'],
    setup_requires=['setuptools_scm'],
    use_scm_version=True,
)
