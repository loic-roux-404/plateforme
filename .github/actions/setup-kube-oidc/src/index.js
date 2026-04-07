import * as core from '@actions/core';

async function run() {
  try {
    // Get inputs
    const dexUrl = core.getInput('dex-url');
    const clientId = core.getInput('dex-client-id');
    const clientSecret = core.getInput('dex-client-secret');
    const k8sApiUrl = core.getInput('k8s-api-url');
    const kubeCa = core.getInput('kube-ca');

    // Step 1: Get GitHub OIDC token
    const oidcToken = await core.getIDToken();

    // Step 2: Exchange for Dex token using fetch
    const authHeader = 'Basic ' + Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
    const body = new URLSearchParams({
      connector_id: 'github-actions',
      grant_type: 'urn:ietf:params:oauth:grant-type:token-exchange',
      subject_token: oidcToken,
      requested_token_type: 'urn:ietf:params:oauth:token-type:id_token',
      subject_token_type: 'urn:ietf:params:oauth:token-type:id_token',
      scope: 'openid email profile'
    });

    const response = await fetch(`${dexUrl}/token`, {
      method: 'POST',
      headers: {
        'Authorization': authHeader,
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: body.toString()
    });

    if (!response.ok) {
      throw new Error(`Dex token exchange failed: ${response.status} ${response.statusText}`);
    }

    const data = await response.json();
    const dexToken = data.access_token;
    if (!dexToken) {
      throw new Error('Failed to retrieve Dex token from response');
    }

    // Mask the token in logs
    core.setSecret(dexToken);

    // Step 3: Generate kubeconfig YAML content as a string
    const kubeconfig = `
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${kubeCa}
    server: ${k8sApiUrl}
  name: plateforme
contexts:
- context:
    cluster: plateforme
    user: github-action
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: github-action
  user:
    token: ${dexToken}
`;

    // Output the token and kubeconfig
    core.setOutput('dex-token', dexToken);
    core.setOutput('kubeconfig-content', kubeconfig.trim());
  } catch (error) {
    core.setFailed(error.message);
  }
}

run();
