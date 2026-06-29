const {
    buildSettlementBatch,
} = require("./settlementBatchBuilder");

const {
    executeSettlementBatch,
} = require("./settlementBatchExecutor");

async function weeklySettlementScheduler() {

    const batch =
        await buildSettlementBatch();

    await executeSettlementBatch(batch);
}

module.exports = {
    weeklySettlementScheduler,
};