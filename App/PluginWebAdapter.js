/* App-owned compatibility adapter. No credentials or configuration data cross this bridge. */
(() => {
  'use strict';
  const nativeFetch = window.fetch.bind(window);
  let stopped = false;
  const report = (kind) => window.webkit?.messageHandlers?.pluginScreen?.postMessage(kind);
  window.addEventListener('pagehide', () => { stopped = true; });
  window.fetch = async function(input, init) {
    if (stopped) throw new Error('Plugin screen closed');
    const request = new Request(input, init);
    const url = new URL(request.url, location.href);
    if (url.protocol !== 'https:' && !(location.hostname === '127.0.0.1' && url.origin === location.origin)) throw new Error('Unsupported plugin request');
    const headers = new Headers(request.headers);
    if (url.origin === location.origin && location.hostname.toLowerCase().endsWith('.devtunnels.ms')) {
      headers.set('X-Tunnel-Skip-AntiPhishing-Page', 'true');
    }
    // Never forward this server's session to another origin or follow a redirect.
    const response = await nativeFetch(new Request(request, {headers, redirect:'error', credentials:url.origin === location.origin ? 'same-origin':'omit'}));
    if (response.status === 401 || response.status === 403) {
      stopped = true;
      report('authentication');
      // Throw before fetchApi can reach its automatic 403 retry branch.
      throw new Error('Plugin session needs reconnection');
    }
    return response;
  };
  // Embedded Browser/Desktop frames own their layout; only the top document gets host chrome.
  if (window.top && window.top !== window) return;
  const addStyle = () => {
    if (!document.documentElement || document.getElementById('a0-plugin-native-style')) return;
    const style = document.createElement('style'); style.id = 'a0-plugin-native-style';
    style.textContent = `
      body > .container,#startup-transition{display:none!important}
      .modal{padding:0!important}
      .modal-inner{width:100%!important;max-width:none!important;max-height:100dvh!important;height:100dvh!important;border-radius:0!important}
      .a0-native-workspace body > .container{display:flex!important;justify-content:flex-end;width:100%;height:100dvh;margin:0;padding:0}
      .a0-native-workspace body > .container > :not(x-component[path="canvas/right-canvas.html"]){display:none!important}
      .a0-native-workspace .container > x-component[path="canvas/right-canvas.html"]{flex:1;justify-content:flex-end;width:100%;height:100%}
      .a0-native-workspace .container > x-component[path="canvas/right-canvas.html"] > div[x-data]{flex:1;justify-content:flex-end}
      .a0-native-workspace #right-canvas{position:relative!important;inset:auto!important;transform:none!important;max-width:100%;height:100%}
      .a0-native-workspace #right-canvas.is-open{width:100%!important;flex:1;margin:0;border:0}
      .a0-native-workspace .right-canvas-surface-panel:not(.is-active){visibility:hidden}
      .a0-native-workspace .right-canvas-resize-handle,.a0-native-workspace .right-canvas-rail,.a0-native-workspace .right-canvas-tabs{display:none!important}
      .a0-native-workspace .right-canvas-icon-button{min-width:44px;min-height:44px}
      .a0-workspace-panel-title{font-size:1rem;margin:0;padding:8px 12px;flex:1;min-width:0;overflow-wrap:anywhere}
      #a0-workspace-home{position:absolute;inset:0;overflow:auto;padding:24px;box-sizing:border-box;max-width:900px;margin:auto;color:var(--color-text);z-index:1}
      #a0-workspace-home h1{font-size:1.6rem;margin:0 0 8px} #a0-workspace-home p{line-height:1.5;color:var(--color-text-secondary,var(--color-text));margin:0 0 24px}
      .a0-workspace-choices{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(140px,100%),1fr));gap:14px}
      .a0-workspace-choices button{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:14px;min-height:144px;padding:20px 12px;text-align:center;border:1px solid var(--color-border);border-radius:20px;background:var(--color-panel);color:var(--color-text);font:inherit;font-weight:600;overflow-wrap:anywhere}
      .a0-workspace-choices button:active{background:var(--color-background);transform:scale(.98)}
      .a0-workspace-choices button:focus-visible{outline:2px solid var(--color-text);outline-offset:3px}
      .a0-workspace-artwork{display:flex;align-items:center;justify-content:center;width:56px;height:56px;border-radius:16px;background:color-mix(in srgb,var(--color-text) 7%,transparent)}
      .a0-workspace-artwork x-icon{font-size:32px!important;width:32px;height:32px;line-height:1}
      .a0-workspace-artwork img{width:40px;height:40px;object-fit:contain}
      body.right-canvas-open #a0-workspace-home,body:has(.modal) #a0-workspace-home{display:none}
    `;
    document.documentElement.appendChild(style);
  };
  addStyle();
  if (!document.documentElement) new MutationObserver((_,observer) => { addStyle(); if(document.documentElement) observer.disconnect(); }).observe(document,{childList:true,subtree:true});
})();
