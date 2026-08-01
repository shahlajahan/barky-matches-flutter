bool isPreShipmentCancellationEligible(
  String status, {
  bool shipmentStarted = false,
}) {
  if (shipmentStarted) return false;
  return const {
    'paid',
    'confirmed',
    'preparing',
  }.contains(status.trim().toLowerCase());
}
