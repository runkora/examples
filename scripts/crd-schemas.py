"""Converts the CustomResourceDefinitions in YAML files to JSON Schemas for
kubeconform, one file per kind and version, named <kind>_<version>.json.

Usage: crd-schemas.py <output dir> <file.yaml>...

Every object schema rejects fields it does not declare. A misspelt field fails
validation. A schema marked x-kubernetes-preserve-unknown-fields accepts any
field, the same as the API server.
"""

import json
import os
import sys

import yaml


def convert(schema):
    if isinstance(schema, list):
        return [convert(item) for item in schema]
    if not isinstance(schema, dict):
        return schema
    out = {}
    for key, value in schema.items():
        if key == "properties":
            # A map of field names to schemas. Its keys are field names, never
            # schema keywords, even a field named "properties".
            out[key] = {name: convert(sub) for name, sub in value.items()}
        else:
            out[key] = convert(value)
    if out.pop("x-kubernetes-int-or-string", False):
        out.pop("type", None)
        out["oneOf"] = [{"type": "string"}, {"type": "integer"}]
    preserve = out.pop("x-kubernetes-preserve-unknown-fields", False)
    if "properties" in out and "additionalProperties" not in out and not preserve:
        out["additionalProperties"] = False
    return out


def main():
    out_dir, paths = sys.argv[1], sys.argv[2:]
    for path in paths:
        with open(path) as f:
            for doc in yaml.safe_load_all(f):
                if not doc or doc.get("kind") != "CustomResourceDefinition":
                    continue
                kind = doc["spec"]["names"]["kind"].lower()
                for version in doc["spec"]["versions"]:
                    schema = convert(version["schema"]["openAPIV3Schema"])
                    name = os.path.join(out_dir, f"{kind}_{version['name']}.json")
                    with open(name, "w") as f_out:
                        json.dump(schema, f_out)


if __name__ == "__main__":
    main()
