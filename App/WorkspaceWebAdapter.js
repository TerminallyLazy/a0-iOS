/* Present registered surfaces as tiles and full-width panels in the native host. */
window.a0PrepareWorkspace = async function () {
  const {store:canvas} = await import(new URL('/components/canvas/right-canvas-store.js',location.origin).href);
  await canvas.init();
  const deadline = Date.now() + 20000;
  while ((!document.getElementById('right-canvas') || canvas._registering) && Date.now() < deadline) {
    await new Promise(resolve => setTimeout(resolve,50));
  }
  if (!document.getElementById('right-canvas') || canvas._registering) throw new Error('Workspace unavailable');
  // The native chat owns selection. A draft can browse tools without creating a server chat.
  canvas.shouldRender = () => true;
  // This host is already a full-screen tool presentation, even on a phone.
  // Panel-only plugins (e.g. Swarm) have no modalPath. Keep the real docked
  // lifecycle at every width instead of asking the server for a nonexistent modal.
  canvas.updateLayoutMode = () => { canvas.isMobileMode = false; canvas.isOverlayMode = false; };
  canvas.applyLayoutState();
  document.documentElement.classList.add('a0-native-workspace');
  const home = document.createElement('section');
  home.id = 'a0-workspace-home';
  const heading = document.createElement('h1'); heading.textContent = 'Workspace'; home.appendChild(heading);
  const description = document.createElement('p'); description.textContent = 'Choose a tool to open.'; home.appendChild(description);
  const choices = document.createElement('div'); choices.className = 'a0-workspace-choices'; home.appendChild(choices);
  const failure = document.createElement('p'); failure.setAttribute('role','alert'); home.appendChild(failure);
  for (const surface of canvas.railSurfaces) {
    const button = document.createElement('button'); button.type = 'button';
    const title = surface.id === 'files' ? 'File Browser' : surface.title;
    button.setAttribute('aria-label',title);
    const artwork = document.createElement('span'); artwork.className = 'a0-workspace-artwork';
    artwork.setAttribute('aria-hidden','true');
    if (surface.image) {
      const image = document.createElement('img'); image.src = surface.image; image.alt = ''; artwork.appendChild(image);
    } else {
      const icon = document.createElement('x-icon'); icon.setAttribute('name',surface.icon || 'web_asset'); artwork.appendChild(icon);
    }
    const label = document.createElement('span'); label.textContent = title;
    button.append(artwork,label);
    button.addEventListener('click',async () => {
      failure.textContent = '';
      try {
        if (await canvas.open(surface.id) === false) failure.textContent = 'This tool cannot open here. Select an existing chat if the tool requires one.';
      } catch { failure.textContent = 'This tool could not be opened. Close the workspace and try again.'; }
    });
    choices.appendChild(button);
  }
  if (!canvas.railSurfaces.length) description.textContent = 'This server has no registered workspace tools.';
  document.body.appendChild(home);
  const header = document.querySelector('.right-canvas-header');
  const panelTitle = document.createElement('h2'); panelTitle.className = 'a0-workspace-panel-title';
  header?.prepend(panelTitle);
  const back = document.querySelector('.right-canvas-close-button');
  if (back) {
    back.setAttribute('aria-label','Back to tools'); back.title = 'Back to tools';
    back.querySelector('x-icon')?.setAttribute('name','arrow_back');
  }
  // The server close glyph has no accessible name; label it in this native presentation.
  const labelCloseButtons = () => {
    document.querySelectorAll('.modal-close').forEach(button => {
      if (!button.hasAttribute('aria-label')) button.setAttribute('aria-label','Close panel');
    });
    document.querySelectorAll('.btn-icon-action[title],.btn-icon-action[data-bs-original-title]').forEach(button => {
      if (!button.hasAttribute('aria-label')) button.setAttribute('aria-label',button.title || button.getAttribute('data-bs-original-title'));
    });
  };
  new MutationObserver(labelCloseButtons).observe(document.body,{childList:true,subtree:true,attributes:true,attributeFilter:["title","data-bs-original-title"]});
  labelCloseButtons();
  // An explicit surface handoff may close the original plugin modal before docking completes.
  // Keep this same browser/session alive once any surface was requested.
  let surfaceOpened = false;
  for (const method of ['open','openModalSurface','dockSurface','undockSurface']) {
    const original = canvas[method].bind(canvas);
    canvas[method] = async (...args) => {
      surfaceOpened = true;
      const result = await original(...args);
      panelTitle.textContent = canvas.activeTitle();
      return result;
    };
  }
  return {hasSurface:() => surfaceOpened || canvas.isOpen};
};
