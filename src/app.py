import base64
import copy
import http
import json
import logging
import random
import sys

import jsonpatch

from flask import Flask, jsonify, request

app = Flask(__name__)


app.logger.setLevel(logging.DEBUG)

@app.route("/mutate", methods=["POST"])
def mutate():
    app.logger.debug(f'Original request: {request.json}')
    spec = request.json["request"]["object"]
    modified_spec = copy.deepcopy(spec)

    try:
        modified_spec["spec"]["hostNetwork"] = True
        app.logger.debug(f'Modified spec: {modified_spec}')
    except KeyError:
        pass
    patch = jsonpatch.JsonPatch.from_diff(spec, modified_spec)
    app.logger.debug(f'Patch: {patch}')
    response = jsonify(
        {
            "apiVersion": "admission.k8s.io/v1",
            "kind": "AdmissionReview",
            "response": {
                "uid": request.json["request"]["uid"],
                "allowed": True,
                "patchType": "JSONPatch",
                "patch": base64.b64encode(str(patch).encode()).decode()
            }
        }
    )
    app.logger.debug(f'Response: {response.json}')
    return response


@app.route("/health", methods=["GET"])
def health():
    return ("", http.HTTPStatus.NO_CONTENT)


if __name__ == "__main__":
    app.run(host="0.0.0.0", debug=True)
