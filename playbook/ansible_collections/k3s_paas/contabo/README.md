# Ansible Collection - k3s_paas.contabo

Documentation for the collection.

Build required pip packages in `pip-packages/` folder :

```
cd pip-packages/contabo-api-utils && \
python -m pip install --upgrade build && python -m build
```

```
pip install -r requirements.txt
ansible-galaxy collection install k3s_paas.contabo
```

## Test

```
OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
ansible-test integration

```