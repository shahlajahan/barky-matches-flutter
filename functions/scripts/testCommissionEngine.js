const { calculateCommission } = require("../commission/commissionEngine");

async function run() {
  try {
    console.log("================================");
    console.log("Taxi Test");
    console.log("================================");

    const financial = await calculateCommission({
      sector: "taxi",

      systemPrice: 1500,

      sellerPrice: 1200,
    });

    console.log(financial);
  } catch (e) {
    console.error(e);
  }
}

run();