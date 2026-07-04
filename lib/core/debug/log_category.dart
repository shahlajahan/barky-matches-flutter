/// Identifies the source domain for a diagnostics log entry.
///
/// Keeping categories strongly typed makes filtering, routing, and future
/// remote transport safer than relying on raw strings throughout the app.
enum LogCategory {
  auth,
  nav,
  firestore,
  storage,
  network,
  payment,
  map,
  location,
  image,
  notification,
  ui,
  performance,
  error,
}
