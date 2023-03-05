#!/usr/bin/python

from ansible.plugins.lookup import LookupBase
from ansible.utils.display import Display
import pfruck_contabo
from uuid import uuid4
from pfruck_contabo.api import secrets_api
from contabo_api_utils.client import authenticated_client, parse_and_validate_credentials

display = Display()

def create_secret(api_client: pfruck_contabo.ApiClient, secret_name: str, value="", secret_type="password"):
    return secrets_api.SecretsApi(api_client).create_secret(
        str(uuid4()), 
        {'name': secret_name, 'value': value, 'type': secret_type}
    )

class LookupModule(LookupBase):
    def run(self, terms, _=None, **kwargs):

        term = terms[0]
        value = kwargs.pop('value', "")

        assert term is not None, "secret name must be provided"
        assert value is not None, "value must be provided"

        type = kwargs.pop('type', "password")

        client_id, client_secret, username, password = parse_and_validate_credentials(
            kwargs.pop('credentials', {}) or {}
        )

        return create_secret(
            authenticated_client(client_id, client_secret, username, password), term, value, type
        )
