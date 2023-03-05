#!/usr/bin/python

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

from ansible.plugins.lookup import LookupBase
from uuid import uuid4
import pfruck_contabo
from pfruck_contabo.api import secrets_api
from contabo_api_utils.client import authenticated_client, parse_and_validate_credentials

def get_secret(api_client: pfruck_contabo.ApiClient, name: str):
    return secrets_api.SecretsApi(api_client).retrieve_secret_list(
        str(uuid4()), name=str(name))

class LookupModule(LookupBase):
    def run(self, terms, _=None, **kwargs):
        client_id, client_secret, username, password = parse_and_validate_credentials(
            kwargs.pop('credentials', {}) or {}
        )

        term = terms[0]

        return get_secret(authenticated_client(client_id, client_secret, username, password), term)
