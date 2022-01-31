from setuptools import setup
from Cython.Build import cythonize

cython_files = ["src/**/*.pyx"]


setup(
    ext_modules = cythonize(cython_files)
)