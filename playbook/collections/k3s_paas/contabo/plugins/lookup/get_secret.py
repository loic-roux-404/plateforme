#!/usr/bin/python

from ansible.plugins.lookup import LookupBase
import pfruck_contabo
from oauthlib.oauth2 import LegacyApplicationClient
from requests_oauthlib import OAuth2Session
from pfruck_contabo.api import secrets_api

CONTABO_API_HOST = 'https://api.contabo.com'

# Well known : https://auth.contabo.com/auth/realms/contabo/.well-known/openid-configuration
CONTABO_AUTH_HOST = 'https://auth.contabo.com/auth/realms/contabo/protocol/openid-connect/token'

configuration = pfruck_contabo.Configuration(
    host = CONTABO_API_HOST
)

def authenticated_client(client_id, client_secret, username, password) -> pfruck_contabo.ApiClient:
    oauth = OAuth2Session(client=LegacyApplicationClient(client_id=client_id))
    access_token = oauth.fetch_token(token_url=CONTABO_AUTH_HOST,
            username=username, password=password, client_id=client_id,
            client_secret=client_secret
    )

    return pfruck_contabo.ApiClient(pfruck_contabo.Configuration(
        access_token = access_token
    ))

def get_secret(api_client: pfruck_contabo.ApiClient, secret_name):
    return secrets_api.SecretsApi(api_client).get_secret(secret_name)

class LookupModule(LookupBase):
    def run(self, term, _=None, **kwargs):
        credentials: dict = kwargs.pop('credentials', {}) or {}

        client_id = credentials.get('client_id')
        client_secret = credentials.get('client_secret')
        username = credentials.get('username')
        password = credentials.get('password')

        assert client_id is not None, "client_id must be provided"
        assert client_secret is not None, "client_secret must be provided"
        assert username is not None, "username must be provided"
        assert password is not None, "password must be provided"

        return get_secret(authenticated_client(client_id, client_secret, username, password), term)
