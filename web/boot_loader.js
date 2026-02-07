(function () {
  var loader = document.getElementById("boot-loader");
  if (!loader) {
    return;
  }

  function hideLoader() {
    loader.classList.add("boot-loader--hidden");
    window.setTimeout(function () {
      if (loader && loader.parentNode) {
        loader.parentNode.removeChild(loader);
      }
    }, 300);
  }

  if (document.readyState === "complete") {
    window.requestAnimationFrame(function () {
      window.addEventListener("flutter-first-frame", hideLoader, { once: true });
    });
  } else {
    window.addEventListener("load", function () {
      window.addEventListener("flutter-first-frame", hideLoader, { once: true });
    }, { once: true });
  }

  window.setTimeout(function () {
    if (loader && !loader.classList.contains("boot-loader--hidden")) {
      var status = loader.querySelector(".boot-loader__status");
      if (status) {
        status.textContent = "Still loading…";
      }
    }
  }, 8000);
})();
