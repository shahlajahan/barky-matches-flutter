const { SECTORS } = require("./commissionTypes");

const taxiStrategy = require("./strategies/taxiStrategy");
const vetStrategy = require("./strategies/vetStrategy");
const groomyStrategy = require("./strategies/groomyStrategy");
const hotelStrategy = require("./strategies/hotelStrategy");
const trainingStrategy = require("./strategies/trainingStrategy");
const petshopStrategy = require("./strategies/petshopStrategy");

module.exports = {
    [SECTORS.TAXI]: taxiStrategy,
    [SECTORS.VET]: vetStrategy,
    [SECTORS.GROOMY]: groomyStrategy,
    [SECTORS.HOTEL]: hotelStrategy,
    [SECTORS.TRAINING]: trainingStrategy,
    [SECTORS.PETSHOP]: petshopStrategy,
};