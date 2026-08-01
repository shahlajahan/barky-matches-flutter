{{flutter_js}}
{{flutter_build_config}}

(function () {
  // Diagnostics only — every call is defensive so this file can never be
  // the thing that breaks startup. window.barkyLog/barkyLogError are
  // defined by index.html's inline script, which always executes first
  // (synchronous, before this file — loaded with `async` — can run). A
  // stale cached index.html without them is still safe: fall back to a
  // plain console call rather than doing nothing, so a version-mismatched
  // deploy still produces *some* trace.
  function log(message) {
    try {
      if (typeof window.barkyLog === 'function') {
        window.barkyLog(message);
      } else {
        console.log('[barky-startup] ' + message);
      }
    } catch (_) {
      // Never let diagnostics throw.
    }
  }

  function logError(source, detail) {
    try {
      if (typeof window.barkyLogError === 'function') {
        window.barkyLogError(source, detail);
      } else {
        console.error('[barky-startup] ' + source, detail);
      }
    } catch (_) {}
  }

  log('flutter_bootstrap.js executing');

  // Best-effort, read-only observation of service-worker state. This does
  // NOT participate in, replace, or duplicate the actual registration —
  // that is still done exclusively by _flutter.loader.load()'s own
  // serviceWorkerSettings below, unchanged from the generated default.
  try {
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.getRegistration().then(function (reg) {
        log('serviceWorker existing registration at boot: ' + (
          !reg ? 'none' :
          reg.active ? 'active' :
          reg.installing ? 'installing' :
          reg.waiting ? 'waiting' : 'present, no worker'
        ));
      }).catch(function (e) {
        logError('serviceWorker.getRegistration', e);
      });
    } else {
      log('serviceWorker API unavailable in this browser');
    }
  } catch (e) {
    logError('serviceWorker observation setup', e);
  }

  log('_flutter.loader.load() starting');

  _flutter.loader.load({
    serviceWorkerSettings: {
      serviceWorkerVersion: {{flutter_service_worker_version}}
    },
    // Everything below is purely observational and, on success, behaves
    // identically to the default (omitted) callback:
    //   (engineInitializer) => engineInitializer.initializeEngine(config)
    //       .then((appRunner) => appRunner.runApp())
    // — see flutter_web_sdk/flutter_js/src/entrypoint_loader.js. `config`
    // is {} in both cases: neither the default nor this file passes a
    // `config` option to .load().
    onEntrypointLoaded: async function (engineInitializer) {
      log('engine initializer resolved (didCreateEngineInitializer received)');
      try {
        const engine = await engineInitializer.initializeEngine({});
        log('engine initialized');
        log('runApp starting');
        await engine.runApp();
        log('runApp() resolved — Dart main() has been entered');
      } catch (e) {
        // Rethrown deliberately: this callback is invoked by Flutter
        // without being awaited (see didCreateEngineInitializer in
        // entrypoint_loader.js), so a rejected promise here becomes a
        // genuine unhandledrejection — caught by index.html's existing
        // startup-only listener, which is still armed at this point.
        logError('engine initialization or runApp', e);
        throw e;
      }
    },
  });
})();
