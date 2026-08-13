{{flutter_js}}
{{flutter_build_config}}

(function () {
  _flutter.loader.load({
    serviceWorkerSettings: {
      serviceWorkerVersion: {{flutter_service_worker_version}}
    },
    onEntrypointLoaded: async function (engineInitializer) {
      try {
        const engine = await engineInitializer.initializeEngine({});
        await engine.runApp();
      } catch (e) {
        throw e;
      }
    },
  });
})();
