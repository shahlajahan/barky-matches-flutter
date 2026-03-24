enum ModerationTargetType {
  dog,
  business,
  user,
  chat,
  adoptionPost,
  lostDog,
  foundDog,
  playdate,
  message,
}

enum ModerationCaseStatus {
  open,
  investigating,
  actionTaken,
  resolved,
  dismissed,
}

enum ModerationQueueStatus {
  pendingReview,
  inReview,
  waitingAction,
  closed,
}

enum ModerationEffectiveStatus {
  clean,
  flagged,
  restricted,
  hidden,
  suspended,
}

enum ModerationPriority {
  low,
  medium,
  high,
  critical,
}

int priorityRank(ModerationPriority p) {
  switch (p) {
    case ModerationPriority.low:
      return 1;
    case ModerationPriority.medium:
      return 2;
    case ModerationPriority.high:
      return 3;
    case ModerationPriority.critical:
      return 4;
  }
}