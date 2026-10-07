/**
 * Host client for docs. Download and include on the host page.
 *
 *   const docs = new DeltaDocs('https://docs.example.com')
 *   docs.open({
 *     // one of: path | document | compiler
 *     path: 'report.dlt',
 *     mode: 'product',
 *     target: 'window',
 *     data: { user: '…', year: 2026 },
 *     tables: { 'Table': rows },
 *     // optional, ASCII only: REST + SignalR; host:// via ${session.header.Name}
 *     auth: { headers: { Authorization: 'Bearer …' } },
 *     overlay: { color: '#000', opacity: 0.35, blur: 4, duration: 0.2 },
 *     // iframe only: optional shell; loading panel (delayed, off when fast)
 *     shell: '#editor-shell',
 *     loading: false,
 *   })
 */

;(function (root) {
  'use strict'

  var READY = 'docs-editor-ready'
  var UI_READY = 'docs-editor-ui-ready'
  var USER_DATA = 'docs-user-data'
  var USER_DATA_ACK = 'docs-user-data-ack'
  var EDITOR_CLOSED = 'docs-editor-closed'
  var DEFAULT_IFRAME = '#delta-docs'
  var SESSION_STYLE_ID = 'delta-docs-session-styles'
  var SESSION_BODY_CLASS = 'delta-docs-session-open'
  var SESSION_BACKDROP_CLASS = 'delta-docs-session__backdrop'
  var SESSION_SHELL_CLASS = 'delta-docs-session__shell'
  var SESSION_LOADING_CLASS = 'delta-docs-session__loading'
  var SESSION_WARM_KEY = 'delta-docs:warm'

  var DEFAULT_OVERLAY = { color: '#000000', opacity: 0.35, blur: 0, duration: 0 }
  var DEFAULT_LOADING = { delayMs: 400, delayMsWarm: 700, minVisibleMs: 200 }
  var LOADING_STAGE_OPEN = 'Загрузка DELTA:DOCS…'
  var LOADING_STAGE_APP = 'Запуск приложения…'
  var LOADING_STAGE_INIT = 'Инициализация…'

  function cloneJson(value) {
    return JSON.parse(JSON.stringify(value))
  }

  function stripSlash(url) {
    return String(url || '').replace(/\/+$/, '')
  }

  function resolveIframe(iframe) {
    if (!iframe) return null
    if (typeof iframe === 'string') return root.document.querySelector(iframe)
    return iframe
  }

  function resolveShell(shell, iframe) {
    if (shell) {
      if (typeof shell === 'string') return root.document.querySelector(shell)
      return shell
    }
    if (!iframe || !iframe.parentElement) return null
    return iframe.parentElement
  }

  function clamp01(n, fallback) {
    if (!Number.isFinite(n)) return fallback
    return Math.min(1, Math.max(0, n))
  }

  function clampBlur(n) {
    if (!Number.isFinite(n) || n < 0) return 0
    return Math.min(64, n)
  }

  function clampDuration(n) {
    if (!Number.isFinite(n) || n < 0) return 0
    return Math.min(5, n)
  }

  function parseHexRgb(hex) {
    var m = /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.exec(String(hex || '').trim())
    if (!m) return null
    var h = m[1]
    if (h.length === 3) {
      return [
        parseInt(h[0] + h[0], 16),
        parseInt(h[1] + h[1], 16),
        parseInt(h[2] + h[2], 16),
      ]
    }
    return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)]
  }

  function resolveOverlayBackground(ov) {
    var opacity = clamp01(ov.opacity, DEFAULT_OVERLAY.opacity)
    var color = String(ov.color || DEFAULT_OVERLAY.color).trim()
    var rgb = parseHexRgb(color)
    if (rgb) return 'rgba(' + rgb[0] + ', ' + rgb[1] + ', ' + rgb[2] + ', ' + opacity + ')'
    return color
  }

  function normalizeOverlayFromOpts(opts) {
    var o = opts && typeof opts === 'object' ? opts : {}
    if (o.overlay == null) return null
    if (typeof o.overlay !== 'object' || Array.isArray(o.overlay)) return null
    var raw = o.overlay
    var hasAny =
      (raw.color != null && String(raw.color).trim() !== '') ||
      raw.opacity != null ||
      raw.blur != null ||
      raw.duration != null
    if (!hasAny) return null
    return {
      color: raw.color != null ? String(raw.color).trim() : DEFAULT_OVERLAY.color,
      opacity: clamp01(
        raw.opacity == null ? DEFAULT_OVERLAY.opacity : Number(raw.opacity),
        DEFAULT_OVERLAY.opacity,
      ),
      blur: clampBlur(raw.blur == null ? DEFAULT_OVERLAY.blur : Number(raw.blur)),
      duration: clampDuration(
        raw.duration == null ? DEFAULT_OVERLAY.duration : Number(raw.duration),
      ),
    }
  }

  function overlayIsActive(ov) {
    return ov != null && ov.opacity > 0
  }

  function clampDelayMs(n, fallback) {
    if (!Number.isFinite(n) || n < 0) return fallback
    return Math.min(10000, n)
  }

  function isSessionWarm() {
    try {
      return root.sessionStorage.getItem(SESSION_WARM_KEY) === '1'
    } catch {
      return false
    }
  }

  function markSessionWarm() {
    try {
      root.sessionStorage.setItem(SESSION_WARM_KEY, '1')
    } catch {
      /* ignore */
    }
  }

  function normalizeLoadingFromOpts(opts) {
    var o = opts && typeof opts === 'object' ? opts : {}
    if (o.loading === false) return null
    var raw = o.loading
    if (raw == null || raw === true) raw = {}
    if (typeof raw !== 'object' || Array.isArray(raw)) return null
    return {
      delayMs: clampDelayMs(
        raw.delayMs == null ? DEFAULT_LOADING.delayMs : Number(raw.delayMs),
        DEFAULT_LOADING.delayMs,
      ),
      delayMsWarm: clampDelayMs(
        raw.delayMsWarm == null ? DEFAULT_LOADING.delayMsWarm : Number(raw.delayMsWarm),
        DEFAULT_LOADING.delayMsWarm,
      ),
      minVisibleMs: clampDelayMs(
        raw.minVisibleMs == null ? DEFAULT_LOADING.minVisibleMs : Number(raw.minVisibleMs),
        DEFAULT_LOADING.minVisibleMs,
      ),
    }
  }

  function ensureSessionStyles() {
    if (root.document.getElementById(SESSION_STYLE_ID)) return
    var style = root.document.createElement('style')
    style.id = SESSION_STYLE_ID
    style.textContent =
      '@keyframes delta-docs-session-backdrop-in{from{opacity:0}to{opacity:1}}' +
      '.' +
      SESSION_BACKDROP_CLASS +
      '{position:fixed;inset:0;z-index:2499;pointer-events:auto;' +
      'animation:delta-docs-session-backdrop-in var(--delta-docs-session-duration,0s) ease-out both;' +
      'background:var(--delta-docs-session-bg,transparent);' +
      '-webkit-backdrop-filter:blur(var(--delta-docs-session-blur,0px));' +
      'backdrop-filter:blur(var(--delta-docs-session-blur,0px))}' +
      'body.' +
      SESSION_BODY_CLASS +
      '{overflow:hidden}' +
      '.' +
      SESSION_SHELL_CLASS +
      '{position:fixed;inset:0;z-index:2500;pointer-events:none;background:transparent!important;overflow:hidden}' +
      '.' +
      SESSION_SHELL_CLASS +
      ' iframe{display:block;width:100%;height:100%;border:0;background:transparent;pointer-events:auto}' +
      '.' +
      SESSION_LOADING_CLASS +
      '{position:absolute;inset:0;z-index:2;display:flex;align-items:center;justify-content:center;' +
      'pointer-events:auto;background:rgba(15,23,42,0.78);color:#cbd5e1}' +
      '.' +
      SESSION_LOADING_CLASS +
      '[hidden]{display:none!important}' +
      '.delta-docs-session__loading-card{display:flex;flex-direction:column;align-items:center;gap:0.85rem;' +
      'box-sizing:border-box;min-width:16.5rem;max-width:18rem;padding:1.25rem 1.5rem;text-align:center}' +
      '.delta-docs-session__loading-spinner{box-sizing:border-box;width:2rem;height:2rem;flex:0 0 2rem;border:2px solid rgba(148,163,184,0.35);' +
      'border-top-color:#94a3b8;border-radius:50%;animation:delta-docs-session-loading-spin 0.85s linear infinite}' +
      '.delta-docs-session__loading-text{margin:0;min-width:14rem;min-height:1.2825rem;font:500 0.95rem/1.35 system-ui,sans-serif;' +
      'white-space:nowrap}' +
      '@keyframes delta-docs-session-loading-spin{to{transform:rotate(360deg)}}'
    root.document.head.appendChild(style)
  }

  function mountHostSession(overlay, shellEl) {
    ensureSessionStyles()
    clearHostSessionDom()

    if (shellEl) {
      shellEl.hidden = false
      shellEl.classList.add(SESSION_SHELL_CLASS)
    }

    if (!overlayIsActive(overlay)) {
      root.document.body.classList.add(SESSION_BODY_CLASS)
      return
    }

    var backdrop = root.document.createElement('div')
    backdrop.className = SESSION_BACKDROP_CLASS
    backdrop.setAttribute('aria-hidden', 'true')
    backdrop.style.setProperty('--delta-docs-session-bg', resolveOverlayBackground(overlay))
    backdrop.style.setProperty('--delta-docs-session-blur', overlay.blur + 'px')
    backdrop.style.setProperty('--delta-docs-session-duration', overlay.duration + 's')
    root.document.body.appendChild(backdrop)
    root.document.body.classList.add(SESSION_BODY_CLASS)
    return backdrop
  }

  function clearHostSessionDom() {
    var nodes = root.document.querySelectorAll('.' + SESSION_BACKDROP_CLASS)
    for (var i = 0; i < nodes.length; i++) nodes[i].remove()
    var shells = root.document.querySelectorAll('.' + SESSION_SHELL_CLASS)
    for (var j = 0; j < shells.length; j++) {
      shells[j].classList.remove(SESSION_SHELL_CLASS)
    }
    root.document.body.classList.remove(SESSION_BODY_CLASS)
  }

  function normalizeMode(mode) {
    if (mode == null || mode === '') return 'product'
    var m = String(mode).toLowerCase()
    if (
      m === 'template' ||
      m === 'product' ||
      m === 'autosave' ||
      m === 'readonly' ||
      m === 'hidden' ||
      m === 'pdf'
    ) {
      return m
    }
    throw new Error(
      'DeltaDocs: mode must be template | product | autosave | readonly | hidden | pdf',
    )
  }

  function normalizeTables(tables) {
    if (!tables || typeof tables !== 'object' || Array.isArray(tables)) return []
    var out = []
    Object.keys(tables).forEach(function (rawName) {
      var name = String(rawName || '').trim()
      if (!name) return
      var rows = tables[rawName]
      out.push({
        name: name,
        rows: Array.isArray(rows) ? cloneJson(rows) : [],
      })
    })
    return out
  }

  function applyActiveTable(tables, activeTable) {
    var name = String(activeTable || '').trim()
    if (!name || !tables.length) return tables
    var found = false
    for (var i = 0; i < tables.length; i++) {
      if (tables[i].name === name) found = true
    }
    if (!found) return tables
    for (var j = 0; j < tables.length; j++) {
      if (tables[j].name === name) tables[j].isActive = true
      else delete tables[j].isActive
    }
    return tables
  }

  function normalizeData(data) {
    if (data == null || typeof data !== 'object' || Array.isArray(data)) return null
    return cloneJson(data)
  }

  function resolveOpenSource(opts) {
    var o = opts && typeof opts === 'object' ? opts : {}
    var path = typeof o.path === 'string' ? o.path.trim() : ''
    var hasPath = !!path
    var hasDocument = o.document != null
    var hasCompiler =
      o.compiler != null && typeof o.compiler === 'object' && !Array.isArray(o.compiler)
    var n = (hasPath ? 1 : 0) + (hasDocument ? 1 : 0) + (hasCompiler ? 1 : 0)
    if (n === 0) {
      throw new Error('DeltaDocs.open: set path | document | compiler (exactly one)')
    }
    if (n > 1) {
      throw new Error('DeltaDocs.open: path | document | compiler are mutually exclusive')
    }
    if (hasPath) return { kind: 'path', path: path }
    if (hasDocument) return { kind: 'document', document: cloneJson(o.document) }
    return { kind: 'compiler', compiler: cloneJson(o.compiler) }
  }

  function assertModeAllowsSource(mode, sourceKind) {
    if (sourceKind === 'path') return
    if (mode === 'autosave' || mode === 'readonly' || mode === 'hidden') {
      throw new Error(
        'DeltaDocs.open: mode ' + mode + ' requires path (pin); document/compiler not supported',
      )
    }
  }

  function normalizeAuth(auth) {
    if (!auth || typeof auth !== 'object' || Array.isArray(auth)) return null
    var h = auth.headers
    if (!h || typeof h !== 'object' || Array.isArray(h)) return null
    var headers = {}
    var n = 0
    Object.keys(h).forEach(function (name) {
      if (h[name] == null) return
      headers[name] = String(h[name])
      n++
    })
    return n ? { headers: headers } : null
  }

  function buildPayload(tables, data, source, auth) {
    var payload = {}
    if (tables.length) payload.tables = tables
    if (data) payload.data = data
    if (source.kind === 'document') payload.document = source.document
    if (source.kind === 'compiler') payload.compiler = source.compiler
    if (auth) payload.auth = auth
    if (
      !payload.tables &&
      payload.data === undefined &&
      payload.document === undefined &&
      payload.compiler === undefined &&
      !payload.auth
    ) {
      return null
    }
    return payload
  }

  function pushUserData(targetWindow, origin, payload) {
    if (!targetWindow || typeof targetWindow.postMessage !== 'function') return false
    try {
      targetWindow.postMessage({ type: USER_DATA, payload: payload }, origin)
      return true
    } catch {
      return false
    }
  }

  function startUserDataPush(getWindow, origin, payload) {
    var n = 0
    var id = root.setInterval(function () {
      var w = typeof getWindow === 'function' ? getWindow() : getWindow
      if (!w || w.closed === true || ++n > 50) {
        root.clearInterval(id)
        return
      }
      pushUserData(w, origin, payload)
    }, 100)
    return id
  }

  function normalizeOverlayQuery(opts) {
    var ov = normalizeOverlayFromOpts(opts)
    if (!ov) return { color: '', opacity: '', blur: '', duration: '' }
    return {
      color: ov.color,
      opacity: ov.opacity,
      blur: ov.blur,
      duration: ov.duration,
    }
  }

  function appendOverlayParams(url, opts) {
    var ov = normalizeOverlayQuery(opts)
    if (ov.color) url.searchParams.set('overlayColor', ov.color)
    if (ov.opacity !== '' && Number.isFinite(ov.opacity)) {
      url.searchParams.set('overlayOpacity', String(ov.opacity))
    }
    if (ov.blur !== '' && Number.isFinite(ov.blur)) {
      url.searchParams.set('overlayBlur', String(ov.blur))
    }
    if (ov.duration !== '' && Number.isFinite(ov.duration)) {
      url.searchParams.set('overlayDuration', String(ov.duration))
    }
  }

  function DeltaDocs(appUrl) {
    this.appUrl = stripSlash(typeof appUrl === 'string' ? appUrl : (appUrl && appUrl.appUrl) || '')
    this._payload = null
    this._iframe = null
    this._popup = null
    this._pushTimer = null
    this._sessionShell = null
    this._loadingDelayTimer = null
    this._loadingHideTimer = null
    this._loadingEl = null
    this._loadingTextEl = null
    this._loadingShownAt = 0
    this._loadingVisible = false
    this._loadingOpts = null
    this._loadingIframe = null
    this._loadingIframeOnLoad = null
    this.onClosed = null
    this.onReady = null
    this._onMessage = this._onMessage.bind(this)
    root.addEventListener('message', this._onMessage)
  }

  DeltaDocs.prototype._appOrigin = function (appUrl) {
    var base = stripSlash(appUrl || this.appUrl)
    if (!base) throw new Error('DeltaDocs: set appUrl (public docs URL)')
    return new URL(base, root.location.href).origin
  }

  DeltaDocs.prototype._stopPush = function () {
    if (this._pushTimer != null) {
      root.clearInterval(this._pushTimer)
      this._pushTimer = null
    }
  }

  DeltaDocs.prototype._clearSession = function () {
    this._clearHostLoading()
    clearHostSessionDom()
    if (this._sessionShell) {
      this._sessionShell.hidden = true
      this._sessionShell = null
    }
  }

  DeltaDocs.prototype._clearHostLoadingTimers = function () {
    if (this._loadingDelayTimer != null) {
      root.clearTimeout(this._loadingDelayTimer)
      this._loadingDelayTimer = null
    }
    if (this._loadingHideTimer != null) {
      root.clearTimeout(this._loadingHideTimer)
      this._loadingHideTimer = null
    }
  }

  DeltaDocs.prototype._clearHostLoading = function () {
    this._clearHostLoadingTimers()
    if (this._loadingIframe && this._loadingIframeOnLoad) {
      this._loadingIframe.removeEventListener('load', this._loadingIframeOnLoad)
    }
    this._loadingIframe = null
    this._loadingIframeOnLoad = null
    if (this._loadingEl) {
      this._loadingEl.remove()
      this._loadingEl = null
    }
    this._loadingTextEl = null
    this._loadingShownAt = 0
    this._loadingVisible = false
    this._loadingOpts = null
  }

  DeltaDocs.prototype._setHostLoadingStage = function (text) {
    if (this._loadingTextEl) this._loadingTextEl.textContent = text
  }

  DeltaDocs.prototype._showHostLoading = function () {
    if (!this._loadingEl || this._loadingVisible) return
    this._loadingVisible = true
    this._loadingShownAt = Date.now()
    this._loadingEl.hidden = false
    this._setHostLoadingStage(LOADING_STAGE_OPEN)
  }

  DeltaDocs.prototype._hideHostLoading = function (markWarm) {
    var self = this
    if (this._loadingDelayTimer != null) {
      root.clearTimeout(this._loadingDelayTimer)
      this._loadingDelayTimer = null
    }
    if (markWarm) markSessionWarm()
    if (!this._loadingEl) return
    if (!this._loadingVisible) {
      this._clearHostLoading()
      return
    }
    var minMs =
      (this._loadingOpts && this._loadingOpts.minVisibleMs) || DEFAULT_LOADING.minVisibleMs
    var wait = Math.max(0, minMs - (Date.now() - this._loadingShownAt))
    this._clearHostLoadingTimers()
    this._loadingHideTimer = root.setTimeout(function () {
      self._loadingHideTimer = null
      self._clearHostLoading()
    }, wait)
  }

  DeltaDocs.prototype._beginHostLoading = function (shellEl, iframe, opts) {
    this._clearHostLoading()
    if (!shellEl) return
    var loadingOpts = normalizeLoadingFromOpts(opts)
    if (!loadingOpts) return
    this._loadingOpts = loadingOpts
    ensureSessionStyles()

    var el = root.document.createElement('div')
    el.className = SESSION_LOADING_CLASS
    el.setAttribute('role', 'status')
    el.setAttribute('aria-live', 'polite')
    el.hidden = true

    var card = root.document.createElement('div')
    card.className = 'delta-docs-session__loading-card'

    var spinner = root.document.createElement('div')
    spinner.className = 'delta-docs-session__loading-spinner'
    spinner.setAttribute('aria-hidden', 'true')

    var text = root.document.createElement('p')
    text.className = 'delta-docs-session__loading-text'
    text.textContent = LOADING_STAGE_OPEN

    card.appendChild(spinner)
    card.appendChild(text)
    el.appendChild(card)
    shellEl.appendChild(el)

    this._loadingEl = el
    this._loadingTextEl = text

    var self = this
    var delay = isSessionWarm() ? loadingOpts.delayMsWarm : loadingOpts.delayMs
    this._loadingDelayTimer = root.setTimeout(function () {
      self._loadingDelayTimer = null
      self._showHostLoading()
    }, delay)

    if (iframe) {
      var onLoad = function () {
        iframe.removeEventListener('load', onLoad)
        if (self._loadingIframeOnLoad === onLoad) {
          self._loadingIframe = null
          self._loadingIframeOnLoad = null
        }
        self._setHostLoadingStage(LOADING_STAGE_APP)
      }
      this._loadingIframe = iframe
      this._loadingIframeOnLoad = onLoad
      iframe.addEventListener('load', onLoad)
    }
  }

  DeltaDocs.prototype._onMessage = function (e) {
    var origin
    try {
      origin = this._appOrigin()
    } catch {
      return
    }
    if (e.origin !== origin) return
    if (!e.data || typeof e.data !== 'object') return

    if (e.data.type === USER_DATA_ACK) {
      this._stopPush()
      return
    }

    if (e.data.type === EDITOR_CLOSED) {
      this._stopPush()
      if (typeof this.onClosed === 'function') this.onClosed()
      else this.close()
      return
    }

    if (e.data.type === UI_READY) {
      this._hideHostLoading(true)
      // Иначе клавиатура (Esc, хоткеи) остаётся у страницы host, пока не кликнут в редактор.
      if (this._iframe) this._iframe.focus()
      return
    }

    if (e.data.type !== READY) return
    this._setHostLoadingStage(LOADING_STAGE_INIT)
    if (typeof this.onReady === 'function') this.onReady()
    if (!e.source || typeof e.source.postMessage !== 'function') return
    e.source.postMessage({ type: USER_DATA, payload: this._payload }, e.origin)
  }

  DeltaDocs.prototype.href = function (options) {
    var opts = options || {}
    var appUrl = stripSlash(opts.appUrl || this.appUrl)
    var origin = this._appOrigin(appUrl)
    var source = resolveOpenSource(opts)
    var mode = normalizeMode(opts.mode)
    assertModeAllowsSource(mode, source.kind)

    var url = new URL(appUrl || origin)
    if (source.kind === 'path') {
      url.searchParams.set('path', source.path)
    } else {
      url.searchParams.set('source', source.kind)
    }

    if (mode !== 'product') url.searchParams.set('mode', mode)

    if (opts.lang) url.searchParams.set('lang', String(opts.lang))

    appendOverlayParams(url, opts)

    var target = String(opts.target || 'window').toLowerCase()
    if (target === 'frame') target = 'iframe'
    if (target !== 'iframe') url.searchParams.set('host', 'popup')

    url.searchParams.set('_', String(Date.now()))

    return url.toString()
  }

  DeltaDocs.prototype.open = function (options) {
    var opts = options || {}
    if (opts.appUrl) this.appUrl = stripSlash(opts.appUrl)

    var source = resolveOpenSource(opts)
    var mode = normalizeMode(opts.mode)
    assertModeAllowsSource(mode, source.kind)

    var tables = applyActiveTable(normalizeTables(opts.tables), opts.activeTable)
    var data = normalizeData(opts.data)
    this._payload = buildPayload(tables, data, source, normalizeAuth(opts.auth))

    var href = this.href(opts)
    var origin = this._appOrigin()
    var target = String(opts.target || 'window').toLowerCase()
    if (target === 'frame') target = 'iframe'

    this._stopPush()
    this._clearSession()

    var overlay = normalizeOverlayFromOpts(opts)

    if (target === 'iframe') {
      var iframe = resolveIframe(opts.iframe || DEFAULT_IFRAME)
      if (!iframe || String(iframe.tagName).toUpperCase() !== 'IFRAME') {
        throw new Error(
          'DeltaDocs.open: target=iframe needs <iframe> (iframe: element | selector)',
        )
      }
      this._iframe = iframe
      this._popup = null
      this._sessionShell = resolveShell(opts.shell, iframe)
      mountHostSession(overlay, this._sessionShell)
      this._beginHostLoading(this._sessionShell, iframe, opts)
      iframe.src = href
      var self = this
      this._pushTimer = startUserDataPush(
        function () {
          return self._iframe && self._iframe.contentWindow
        },
        origin,
        this._payload,
      )
      return iframe
    }

    this._iframe = null
    this._popup = root.open(href, opts.windowName || 'delta-docs-editor')
    var popup = this._popup
    this._pushTimer = startUserDataPush(
      function () {
        return popup && !popup.closed ? popup : null
      },
      origin,
      this._payload,
    )
    return this._popup
  }

  DeltaDocs.prototype.close = function () {
    this._stopPush()
    if (this._iframe) this._iframe.src = 'about:blank'
    if (this._popup && !this._popup.closed) this._popup.close()
    this._clearSession()
  }

  DeltaDocs.prototype.destroy = function () {
    root.removeEventListener('message', this._onMessage)
    this.close()
  }

  root.DeltaDocs = DeltaDocs
})(typeof window !== 'undefined' ? window : this)
