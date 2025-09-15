from flask import Flask, request, send_from_directory
import subprocess

app = Flask(__name__, static_folder='/usr/local/share')

@app.route('/')
def gui():
    return send_from_directory(app.static_folder, 'universal-ssh-gui.html')

@app.route('/apply-keys', methods=['POST'])
def apply_keys():
    data = request.json
    keys = data.get('keys', [])

    # Write config
    with open('/etc/pve/universal-ssh-keys.cfg','w') as f:
        f.write('[datacenter]\nenabled = 1\nkeys = [\n')
        for k in keys:
            f.write(f'"{k}",\n')
        f.write(']\n[nodes]\nenabled = 1\nkeys = [\n')
        for k in keys:
            f.write(f'"{k}",\n')
        f.write(']\n')

    # Run apply script
    subprocess.run(['/usr/local/bin/apply-universal-keys.sh'])

    return "Keys applied, VMs rebooted, and online."

