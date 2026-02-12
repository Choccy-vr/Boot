window.addEventListener("load", function () {
  if (!window._flutter || !window._flutter.loader) {
    return;
  }

  window._flutter.loader.load({
    onEntrypointLoaded: function (engineInitializer) {
      engineInitializer
        .initializeEngine({ renderer: "html" })
        .then(function (appRunner) {
          return appRunner.runApp();
        });
    },
  });
});
