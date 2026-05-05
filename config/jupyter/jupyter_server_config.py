import os

c.ServerApp.ip = "127.0.0.1"
c.ServerApp.port = 8888
c.ServerApp.open_browser = False
c.ServerApp.allow_root = False
c.ServerApp.token = os.environ.get("ACABOS_JUPYTER_TOKEN", "")
c.ServerApp.password = ""
c.ServerApp.allow_origin = ""
c.ServerApp.collaborative = True
c.ServerApp.root_dir = os.environ.get("ACABOS_JUPYTER_ROOT", "")
