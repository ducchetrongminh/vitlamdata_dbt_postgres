"""Shared setup for el/<source>/pipeline.py. Call setup(__file__) first."""

import os
import tomllib
from string import Template

import dlt
from dlt.common.configuration.providers import CustomLoaderDocProvider

CREDENTIALS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "credentials.toml")


def _expand(value):
    # Template.substitute raises KeyError on an unset var instead of passing "${VAR}" on.
    if isinstance(value, dict):
        return {k: _expand(v) for k, v in value.items()}
    return Template(value).substitute(os.environ) if isinstance(value, str) else value


def _load_credentials():
    with open(CREDENTIALS, "rb") as f:
        return _expand(tomllib.load(f))


def setup(pipeline_file):
    # dlt reads .dlt/ from the working directory; use the source's own folder, so
    # each source keeps its config.toml and the script runs from anywhere.
    os.environ.setdefault("DLT_PROJECT_DIR", os.path.dirname(os.path.abspath(pipeline_file)))
    dlt.config.register_provider(CustomLoaderDocProvider("credentials.toml", _load_credentials, locations=[CREDENTIALS]))
