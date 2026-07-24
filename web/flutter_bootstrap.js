{{flutter_js}}
{{flutter_build_config}}

// Newron's own compact digest cache provides the offline reading path. Flutter
// now emits only a self-unregistering legacy service worker, so do not register
// it and force an avoidable reload on first launch.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "/canvaskit/",
  },
});
