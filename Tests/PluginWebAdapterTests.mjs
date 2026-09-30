import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
const source = readFileSync(new URL('../App/PluginWebAdapter.js',import.meta.url),'utf8');
function fixture(status=200,origin='https://server.test',subframe=false) {
  const requests=[],events=[],listeners={},styles=[];
  const window={fetch:async request=>{requests.push(request);return new Response('{}',{status});},addEventListener:(name,fn)=>listeners[name]=fn,webkit:{messageHandlers:{pluginScreen:{postMessage:kind=>events.push(kind)}}}};
  if(subframe) window.top={};
  const document={documentElement:{appendChild(style){styles.push(style);}},getElementById:()=>null,createElement:()=>({})};
  vm.runInNewContext(source,{window,document,Request,Response,Headers,URL,location:new URL(origin)});
  return {window,requests,events,listeners,styles};
}
test('403 throws before the WebUI can automatically retry and freezes the expired session',async()=>{
  const f=fixture(403);
  await assert.rejects(f.window.fetch('https://server.test/api/plugins',{method:'POST',body:'{"action":"save_config"}'}));
  await assert.rejects(f.window.fetch('https://server.test/api/plugins',{method:'POST'}));
  assert.equal(f.requests.length,1);assert.deepEqual(f.events,['authentication']);
});
test('same-origin uses session and rejects automatic redirects',async()=>{
  const f=fixture();await f.window.fetch('https://server.test/api/plugins',{method:'POST',body:'{}'});
  assert.equal(f.requests[0].credentials,'same-origin');assert.equal(f.requests[0].redirect,'error');assert.equal(await f.requests[0].text(),'{}');
});
test('cross-origin resources never receive the server credentials',async()=>{
  const f=fixture();await f.window.fetch('https://cdn.test/image.png',{credentials:'include'});
  assert.equal(f.requests[0].credentials,'omit');assert.equal(f.requests[0].redirect,'error');
});
test('pagehide blocks subsequent work and insecure external URLs never send',async()=>{
  const f=fixture();await assert.rejects(f.window.fetch('http://external.test/api'));
  f.listeners.pagehide();await assert.rejects(f.window.fetch('https://server.test/api/plugins'));
  assert.equal(f.requests.length,0);
});

test('tunnel warning header is added only to the connected Dev Tunnels origin',async()=>{
  const f=fixture(200,'https://fixture-5000.use.devtunnels.ms');
  await f.window.fetch('https://fixture-5000.use.devtunnels.ms/components/plugin.html');
  await f.window.fetch('https://cdn.test/plugin.html');
  assert.equal(f.requests[0].headers.get('X-Tunnel-Skip-AntiPhishing-Page'),'true');
  assert.equal(f.requests[1].headers.get('X-Tunnel-Skip-AntiPhishing-Page'),null);
  const spoof=fixture(200,'https://devtunnels.ms.attacker.test');
  await spoof.window.fetch('https://devtunnels.ms.attacker.test/plugin.html');
  assert.equal(spoof.requests[0].headers.get('X-Tunnel-Skip-AntiPhishing-Page'),null);
});

test('embedded frames retain their own layout while preserving request protection',async()=>{
  const f=fixture(200,'https://server.test',true);
  assert.equal(f.styles.length,0);
  await f.window.fetch('https://server.test/desktop/input',{method:'POST'});
  assert.equal(f.requests[0].credentials,'same-origin');
  assert.equal(f.requests[0].redirect,'error');
  assert.equal(fixture().styles.length,1);
});
