const {
    getCommissionConfig,
} = require("./commissionRepository");

const strategyRegistry = require("./strategyRegistry");

async function calculateCommission({
    sector,
    ...context
}) {
    const config =
        await getCommissionConfig(sector);

    if (!config.enabled) {
        throw new Error(
            `${sector} commission is disabled.`
        );
    }

    const strategy =
        strategyRegistry[sector];

    if (!strategy) {
        throw new Error(
            `No strategy registered for ${sector}`
        );
    }

    return strategy.calculate({
        config,
        ...context,
    });
}

module.exports = {
    calculateCommission,
};