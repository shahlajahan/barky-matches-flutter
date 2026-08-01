const REWARD_RULE_VERSION = "creator-ledger-v1";

const REWARD_RULES = Object.freeze({
  user: Object.freeze([
    Object.freeze({ through: 100, amount: 20 }),
    Object.freeze({ through: 250, amount: 30 }),
    Object.freeze({ through: 500, amount: 40 }),
    Object.freeze({ through: Number.POSITIVE_INFINITY, amount: 50 }),
  ]),
  partner: Object.freeze([
    Object.freeze({ through: 10, amount: 300 }),
    Object.freeze({ through: 30, amount: 400 }),
    Object.freeze({ through: Number.POSITIVE_INFINITY, amount: 500 }),
  ]),
});

function rewardForLead(leadType, priorLeadCount) {
  const rules = REWARD_RULES[leadType];
  if (!rules || !Number.isInteger(priorLeadCount) || priorLeadCount < 0) {
    throw new Error(`Unsupported reward lead type: ${leadType}`);
  }

  const sequence = priorLeadCount + 1;
  const rule = rules.find((candidate) => sequence <= candidate.through);
  return { sequence, amount: rule.amount };
}

module.exports = { REWARD_RULE_VERSION, REWARD_RULES, rewardForLead };
