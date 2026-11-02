{{flutter_js}}
{{flutter_build_config}}

// Start downloading the rendering engine right away, in parallel with main.dart.js
// (otherwise it only starts once the app code has finished downloading).
(function () {
  var chromium = typeof Intl.v8BreakIterator !== "undefined" && typeof Intl.Segmenter !== "undefined";
  var base = "https://www.gstatic.com/flutter-canvaskit/" + _flutter.buildConfig.engineRevision + (chromium ? "/chromium/" : "/");
  [["canvaskit.js", "script"], ["canvaskit.wasm", "fetch"]].forEach(function (file) {
    var link = document.createElement("link");
    link.rel = "preload";
    link.href = base + file[0];
    link.as = file[1];
    link.crossOrigin = "anonymous";
    document.head.appendChild(link);
  });
})();

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
