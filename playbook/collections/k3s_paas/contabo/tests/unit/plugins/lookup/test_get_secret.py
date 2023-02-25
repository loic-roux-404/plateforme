import unittest
from ansible_collections.k3s_paas.contabo.plugins.lookup.get_secret import LookupModule

class Test(unittest.TestCase):

    def test_run(self):
        result = LookupModule(None).run("example", credentials = {
                "client_id": "client_id",
                "client_secret": "client_secret",
                "username": "username",
                "password": "password"
            })
        self.assertEqual(result,"example_value")
