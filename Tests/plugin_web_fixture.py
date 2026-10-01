"""Disposable HTTPS fixture: real WebUI assets, synthetic in-memory APIs; no Agent Zero runtime.

Requires --source pointing to an existing Agent Zero checkout and a test-only TLS certificate.
No private source paths, usr directories, credentials or request bodies are logged or served.
"""
import argparse
import json
import mimetypes
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import ssl
from urllib.parse import urlsplit

parser = argparse.ArgumentParser()
parser.add_argument('--source', type=Path, required=True)
parser.add_argument('--cert', required=True)
parser.add_argument('--key', required=True)
parser.add_argument('--port', type=int, default=18447)
parser.add_argument('--host-fixture', action='store_true')
args = parser.parse_args()
webui = (args.source / 'webui').resolve()
assert (webui / 'index.html').is_file()
config = {'label': 'Original fixture value'}
actions = 0
rejections = 0
interstitial = False
root_documents = 0
direct_documents = 0
workspace_manifest = {'js':{'right_canvas_register_surfaces':['/extensions/webui/right_canvas_register_surfaces/register-files.js','/fixture/register-surfaces.js']},'html':{'right-canvas-panels':['/extensions/webui/right-canvas-panels/files-panel.html','/fixture/surface-panels.html']}}

def fixture_panel(surface):
    title = {'browser':'Browser','desktop':'Desktop','editor':'Editor','fixture-surface':'Plugin Panel','swarm':'Swarm'}[surface]
    return f'<section x-data="{{count:0}}"><h2>Fixture {title}</h2><button @click="count++">Use {title}</button><p x-text="\'Completed interactions: \' + count"></p><input aria-label="{title} text" value="Synthetic content"><iframe title="Desktop interaction" src="/fixture/desktop-frame.html"></iframe></section>' if surface == 'desktop' else f'<section x-data="{{count:0}}"><h2>Fixture {title}</h2><button @click="count++">Use {title}</button><p x-text="\'Completed interactions: \' + count"></p><input aria-label="{title} text" value="Synthetic content"></section>'

# Theme tests use synthetic palettes only; no owner configuration is read.
theme_mode = 'disabled'
theme_keys = ['background','text','text-muted','primary','secondary','accent','message-bg','highlight','message-text','panel','border','input','input-focus','chat-background','error-text','warning-text','table-row']
def palette(mode):
    values = dict.fromkeys(theme_keys, '#E3F6FF' if mode == 'dark' else '#163647')
    values.update({'background':'#071C28' if mode == 'dark' else '#F5FCFF', 'panel':'#0B2635' if mode == 'dark' else '#E7F4F8', 'input':'#123042' if mode == 'dark' else '#D9EDF4', 'primary':'#67C7E9' if mode == 'dark' else '#176B8A', 'text-muted':'#B6DBE9' if mode == 'dark' else '#466879', 'border':'#39748BA8','message-bg':'#143A4E' if mode == 'dark' else '#FFFFFF'})
    return values
def theme_config():
    if theme_mode == 'custom':
        dark, light = palette('dark'), palette('light')
        dark.update({'panel':'hsl(280 45% 16%)','primary':'plum','border':'#AA66CC80'})
        light.update({'panel':'hsl(280 45% 94%)','primary':'rebeccapurple'})
        return {'theme':'custom-fixture','custom_themes':[{'id':'custom-fixture','name':'Fixture Violet','dark':dark,'light':light,'gradient':{'enabled':True,'angle':150,'stops':['#201035','#321650','#102A40']}}]}
    return {'theme':'ocean','custom_themes':[]}

plugin = {'name':'fixture-plugin','display_name':'Fixture Plugin','description':'Disposable HTTPS fixture using real WebUI components.','is_custom':True,'has_main_screen':True,'has_config_screen':True,'per_project_config':True,'per_agent_config':True,'toggle_state':'enabled'}

class Handler(BaseHTTPRequestHandler):
    def setup(self):
        # Handshake in this request's worker, never in the listener's accept loop.
        # WebKit may open speculative connections before sending a handshake.
        self.request.settimeout(15)
        self.request.do_handshake()
        super().setup()
    def log_message(self, *args): pass
    def send(self, payload, status=200, content_type='application/json', headers=None):
        data = json.dumps(payload).encode() if content_type == 'application/json' and not isinstance(payload, bytes) else payload
        self.send_response(status)
        self.send_header('Content-Type',content_type)
        self.send_header('Content-Length',str(len(data)))
        for key,value in (headers or {}).items(): self.send_header(key,value)
        self.end_headers()
        try: self.wfile.write(data)
        except (BrokenPipeError,ConnectionResetError): pass
    def authenticated(self): return 'session_fixture=synthetic-session' in self.headers.get('Cookie','')
    def do_POST(self):
        global actions, rejections, root_documents, direct_documents
        raw = self.rfile.read(min(int(self.headers.get('Content-Length','0')),1048576))
        path = urlsplit(self.path).path
        if path == '/fixture/diagnostic':
            print('Synthetic WebUI diagnostic:', raw.decode(errors='replace')[:1200], flush=True); return self.send({})
        if path == '/login':
            actions = 0; rejections = 0; root_documents = 0; direct_documents = 0; config.clear(); config.update(label="Original fixture value")
            return self.send(b'',302,'text/plain',{'Location':'/','Set-Cookie':'session_fixture=synthetic-session; Path=/; Secure; HttpOnly; SameSite=Lax'})
        if not self.authenticated(): return self.send({},401)
        if self.headers.get('X-CSRF-Token') != 'fixture-csrf': return self.send({},403)
        try: body = json.loads(raw or b'{}')
        except ValueError: body = {}
        body = body if isinstance(body,dict) else {}
        action = body.get('action')
        if args.host_fixture and path == '/api/plugins/_a0_connector/v1/capabilities':
            return self.send({'protocol':'a0-connector.v1','features':['launcher_gateway','host_tasks_v1']})
        if args.host_fixture and path == '/api/plugins/_a0_connector/v1/launcher_gateway_status':
            return self.send({'connected':True,'multiple_hosts':False,'gateway':{'host_label':'Fixture Mac'}})
        if args.host_fixture and path == '/api/plugins/_a0_connector/v1/host_status':
            return self.send({'version':1,'context_id':'synthetic-chat','state':'connected','host_label':'Fixture Mac','target_id':'a'*64,'generation':'b'*64,'bound':False,'binding_current':False,'capabilities':{name:{'ready':name=='browser','state':'ready' if name=='browser' else 'off'} for name in ['browser','computer_use','files','file_write','code_execution']}})
        if path == '/api/plugins/_plugin_installer/plugin_install' and action == 'fetch_index':
            return self.send({'success':True,'index':{'plugins':{'fixture-plugin':{'title':'Fixture Plugin','description':'Synthetic theme coverage for Plugin Hub.','tags':['Utilities'],'github':'https://github.com/example/fixture'}}},'installed_plugins':['fixture-plugin']})
        if path == '/api/plugins_list': return self.send({'ok':True,'plugins':[plugin]})
        if path == '/api/plugins':
            if body.get('plugin_name') == 'selectable_theme':
                if theme_mode == 'missing': return self.send({'ok':False},404)
                if action == 'get_toggle_status': return self.send({'ok':True,'status':'disabled' if theme_mode == 'disabled' else 'enabled'})
                if action == 'get_config': return self.send({'ok':True,'data':theme_config()})
            if action in ('get_config','get_default_config'): return self.send({'ok':True,'data':config.copy() if action == 'get_config' else {'label':'Default fixture value'},'loaded_path':'','loaded_project_name':'','loaded_agent_profile':''})
            if action == 'save_config': config.update(body.get('settings',{})); return self.send({'ok':True})
            if action == 'get_toggle_status': return self.send({'ok':True,'status':'enabled','loaded_path':'','loaded_project_name':'','loaded_agent_profile':''})
            if action == 'list_configs': return self.send({'ok':True,'data':[]})
            return self.send({'ok':True})
        if path == '/api/plugins/fixture-plugin/action': actions += 1; return self.send({'ok':True,'count':actions})
        if path == '/api/plugins/fixture-plugin/reject': rejections += 1; return self.send({},403)
        if path == '/api/projects': return self.send({'ok':True,'data':[]})
        if path == '/api/agents': return self.send({'ok':True,'data':[]})
        if path == '/api/load_webui_extensions': return self.send({'ok':True,'extensions':[]})
        if path == '/api/plugins/_model_config/model_config_get': return self.send({'model_configured':True,'config':{},'chat_providers':[],'embedding_providers':[]})
        if path == '/api/poll':
            fixture = json.loads((Path(__file__).parent/'A0CoreTests/Fixtures/full.json').read_text())
            fixture['context'] = ''; fixture['contexts'] = []; fixture['tasks'] = []; fixture['logs'] = []; fixture['log_guid']='fixture'; fixture['log_version']=0
            if args.host_fixture:
                fixture['context'] = body.get('context') or ''
                fixture['contexts'] = [{'id':'synthetic-chat','name':'Host fixture','running':False}]
            return self.send(fixture)
        return self.send({'ok':True,'data':[],'extensions':[],'notifications':[],'version':0})
    def do_GET(self):
        global interstitial, root_documents, direct_documents, theme_mode
        path = urlsplit(self.path).path
        if path.startswith('/fixture/theme/'):
            mode = path.rsplit('/',1)[-1]
            if mode in ['disabled','ocean','custom','invalid','missing']: theme_mode = mode
            return self.send({'ok':True})
        if path == '/plugins/selectable_theme/webui/themes.css':
            if not self.authenticated(): return self.send({},401)
            if theme_mode == 'invalid': return self.send(b'<html>Unexpected theme document</html>',content_type='text/html')
            css = ''.join('body[data-selectable-theme="ocean"].'+mode+'-mode {'+''.join('--color-'+key+':'+value+';' for key,value in palette(mode).items())+'}' for mode in ['dark','light'])
            return self.send(css.encode(),content_type='text/css')
        if path in ('/fixture/interstitial/on' ,'/fixture/interstitial/off'):
            interstitial = path.endswith('/on'); return self.send({'ok':True})
        if path in ('/','/index.html','/ui/index') and interstitial:
            return self.send(b'<html><head><title>Tunnel notice fixture</title></head><body><main>Continue to the tunnel</main></body></html>',content_type='text/html')
        if path == '/fixture/register-surfaces.js':
            return self.send(b"export default function(canvas){ for(const [id,title,icon] of [['browser','Browser','language'],['desktop','Desktop','desktop_windows'],['editor','Editor','description'],['fixture-surface','Plugin Panel','extension']]) canvas.registerSurface({id,title,icon,order:20,modalPath:'/fixture/surface/'+id+'.html',open:async()=>{}}); canvas.registerSurface({id:'swarm',title:'Swarm',icon:'group_work',order:30}); canvas.registerSurface({id:'restricted',title:'Chat-required tool',icon:'lock',order:40,canOpen:()=>false}); }",content_type='text/javascript')
        if path == '/fixture/surface-panels.html':
            panels = ''.join(f'<div class="right-canvas-surface-panel" data-surface-id="{surface}" :class="{{\'is-active\':$store.rightCanvas.isSurfaceVisible(\'{surface}\'),\'is-mounted\':$store.rightCanvas.isSurfaceRendered(\'{surface}\')}}">{fixture_panel(surface)}</div>' for surface in ['browser','desktop','editor','fixture-surface','swarm'])
            return self.send(panels.encode(),content_type='text/html')
        if path.startswith('/fixture/surface/'):
            surface = path.rsplit('/',1)[-1].removesuffix('.html')
            if surface not in ['browser','desktop','editor','fixture-surface']: return self.send({},404)
            return self.send(('<html><head><title>Fixture surface</title></head><body>'+fixture_panel(surface)+'</body></html>').encode(),content_type='text/html')
        if path == '/fixture/desktop-frame.html':
            return self.send(b'<html><body><div class="container"><button onclick="this.textContent=\'Desktop input received\'">Desktop frame action</button></div></body></html>',content_type='text/html')
        if path == '/api/download_work_dir_file':
            if not self.authenticated(): return self.send({},401)
            return self.send(b'Synthetic workspace export\n',content_type='application/octet-stream',headers={'Content-Disposition':'attachment; filename="workspace-note.md"'})
        if path == '/api/get_work_dir_files':
            return self.send({'data':{'current_path':'/a0/fixture','parent_path':'/a0','entries':[{'name':'workspace-note.md','path':'/a0/fixture/workspace-note.md','is_dir':False,'type':'unknown','size':24,'modified':0}]}})
        if path == '/fixture/counts': return self.send({'actions':actions,'rejections':rejections,'root_documents':root_documents,'direct_documents':direct_documents})
        if path == '/fixture/identity': return self.send({'fixture':'a0-plugin-web-fixture-v1'})
        if path == '/api/csrf_token':
            if not self.authenticated(): return self.send(b'',302,'text/plain',{'Location':'/login'})
            return self.send({'ok':True,'token':'fixture-csrf','runtime_id':'fixture'})
        if path == '/plugins/fixture-plugin/webui/config.html':
            return self.send(b'''<html><head><title>Fixture configuration</title></head><body><label>Fixture label <input aria-label="Fixture label" x-model="config.label"></label><p x-text="config.label"></p></body></html>''',content_type='text/html')
        if path == '/plugins/fixture-plugin/webui/main.html':
            return self.send(b'''<html><head><title>Fixture main screen</title><script type="module">import {callJsonApi} from '/js/api.js'; window.fixtureAction=()=>callJsonApi('/plugins/fixture-plugin/action',{}); window.fixtureReject=()=>callJsonApi('/plugins/fixture-plugin/reject',{}); window.fixturePanel=async()=>{const {store}=await import(new URL('/components/canvas/right-canvas-store.js',location.origin).href); if(store.isMobileMode){await store.open('fixture-surface');await window.closeModal('/plugins/fixture-plugin/webui/main.html');}else{await store.dockSurface('fixture-surface',{sourceModalPath:'/plugins/fixture-plugin/webui/main.html'});}};</script></head><body><div x-data="{count:0}"><h2>Interactive fixture</h2><button @click="count=(await window.fixtureAction()).count">Run fixture action</button><p x-text="'Completed actions: '+count"></p><button @click="await window.fixtureReject()">Reject fixture request</button><button onclick="window.location.assign('/')">Replace fixture document</button><button onclick="window.fixturePanel()">Open fixture panel</button></div></body></html>''',content_type='text/html')
        if path.startswith('/socket.io'): return self.send({},404)
        public_root = webui
        # Mirror the real server: / is the document-replacing splash, /index.html is the direct shell.
        if path == '/': root_documents += 1
        if path == '/index.html': direct_documents += 1
        relative = 'splash.html' if path == '/' else 'index.html' if path == '/ui/index' else path.lstrip('/')
        if path.startswith('/extensions/webui/'):
            public_root = (args.source / 'extensions' / 'webui').resolve()
            relative = path.removeprefix('/extensions/webui/')
        if path.startswith('/plugins/_') and '/webui/' in path:
            public_root = (args.source / 'plugins').resolve()
            relative = path.removeprefix('/plugins/')
        file = (public_root / relative).resolve()
        if not file.is_relative_to(public_root) or not file.is_file(): return self.send({},404)
        content = file.read_bytes()
        if file.name == 'index.html':
            diagnostic = b'''<script>window.addEventListener('error', e => {fetch('/fixture/diagnostic',{method:'POST',body:JSON.stringify({message:e.message,stack:e.error?.stack})})});window.addEventListener('unhandledrejection', e => {fetch('/fixture/diagnostic',{method:'POST',body:JSON.stringify({message:String(e.reason),stack:e.reason?.stack})})});</script>'''
            content = content.replace(b'<head>', b'<head>'+diagnostic)
            # The fixture omits server extension registration; provide its two sidebar teleport slots.
            content = content.replace(b'<body class="dark-mode device-pointer" x-data>', b'<body class="dark-mode device-pointer" x-data><div id="sidebar-quick-actions-dropdown-slot-start"></div><div id="sidebar-quick-actions-dropdown-slot-end"></div>')
            replacements={'runtime_id':'fixture','runtime_is_development':'false','logged_in':'true','user_timezone_setting':'UTC','user_time_format_setting':'24','user_ui_control_visibility':'{}','webui_extension_manifest':json.dumps(workspace_manifest),'version_no':'fixture','version_time':'fixture'}
            for key,value in replacements.items(): content=content.replace(('{{'+key+'}}').encode(),value.encode())
        return self.send(content,content_type=mimetypes.guess_type(file.name)[0] or 'application/octet-stream')

ThreadingHTTPServer.request_queue_size = 64
server = ThreadingHTTPServer(('127.0.0.1',args.port),Handler)
context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER); context.load_cert_chain(args.cert,args.key)
server.socket=context.wrap_socket(server.socket,server_side=True,do_handshake_on_connect=False)
print(f'Fixture listening at https://127.0.0.1:{server.server_port}',flush=True)
server.serve_forever()
