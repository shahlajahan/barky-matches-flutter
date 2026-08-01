const assert = require("node:assert/strict");
const test = require("node:test");

const {
  REWARD_RULE_VERSION,
  rewardForLead,
} = require("../src/creator/rewardRules");

test("user lead reward tiers", () => {
  assert.equal(REWARD_RULE_VERSION, "creator-ledger-v1");
  assert.equal(rewardForLead("user", 0).amount, 20);
  assert.equal(rewardForLead("user", 100).amount, 30);
  assert.equal(rewardForLead("user", 250).amount, 40);
  assert.equal(rewardForLead("user", 500).amount, 50);
});

test("partner lead reward tiers", () => {
  assert.equal(rewardForLead("partner", 0).amount, 300);
  assert.equal(rewardForLead("partner", 10).amount, 400);
  assert.equal(rewardForLead("partner", 30).amount, 500);
});
