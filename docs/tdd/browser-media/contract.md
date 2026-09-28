# Browser captures

Browser screenshots opt in through the existing server log contract, not arbitrary Markdown images. The native client reads `kvps.browser_snapshot` (path/a0_path, URI revision, MIME and chat context) and the legacy `kvps.Screenshot` `img://` marker on tool activity. Explicit ephemeral snapshots have no file download and remain absent. A structured snapshot for another chat never falls back to a legacy URI.

Source reference: `plugins/_browser/tools/browser.py::_record_history_screenshot` writes these fields. `api/image_get.py::ImageGet` serves raster bytes through authenticated GET `/api/image_get?path=...`; the existing WebUI uses the same endpoint. Backend source was read only.

The request is constructed from the authenticated server origin, with separately encoded path query, Origin, session cookie and CSRF headers. URLSession blocks redirects, caches and shared cookie stores. Production download stops at 8 MiB (declared size checked before reading; streaming bound while reading). Native decoding checks dimensions up to 16,000 per axis / 40 million pixels and downsamples to 1,400px. SVG, HTML, unsupported types, traversal, remote paths and malformed cache suffixes do not render. Authentication epoch, connection generation, chat ID and log epoch fence completion. Images are transient, canceled/cleared when the view or foreground scope changes.

Collapsed activity displays its three latest captures, with earlier captures available in activity details. Stable IDs combine log number and capture path/revision. Tapping opens a contained popover with a close control, never a fullscreen cover. Loading, unavailable and explicit Retry states use native controls.

RED: focused tests failed because the new projection API did not exist. GREEN: 7 BrowserScreenshotTests pass, including 7 malicious-path cases, structured context rejection, legacy normalization, authenticated request construction, redirect/HTML/SVG/size refusal and disconnect gating. Synthetic UI fixture and BrowserScreenshotUITests are authored; final build/device and visual acceptance are recorded by the parent task. These fixtures do not establish live browser capture acceptance.
