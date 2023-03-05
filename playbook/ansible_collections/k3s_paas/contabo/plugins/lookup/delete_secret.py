#!/usr/bin/python

from ansible.plugins.lookup import LookupBase
from ansible.utils.display import Display
import pfruck_contabo
from uuid import uuid4
from pfruck_contabo.api import secrets_api
from contabo_api_utils.client import authenticated_client, parse_and_validate_credentials

display = Display()

def delete_secret(api_client: pfruck_contabo.ApiClient, name: str):
    secret = secrets_api.SecretsApi(api_client).retrieve_secret_list(
        str(uuid4()), name=str(name))

    if secret is not None:
        return secrets_api.SecretsApi(api_client).delete_secret(str(uuid4()), secret.id)

class LookupModule(LookupBase):
    def run(self, terms, _=None, **kwargs):

        term = terms[0]

        assert term is not None, "secret name must be provided"

        client_id, client_secret, username, password = parse_and_validate_credentials(
            kwargs.pop('credentials', {}) or {}
        )

        return delete_secret(
            authenticated_client(client_id, client_secret, username, password), term
        )
